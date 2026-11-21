// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
//! Native iOS frontend boundary. Flutter clients never register here.
use crate::{flutter, flutter_ffi as ffi};
use hbb_common::{
    anyhow::{anyhow, bail},
    config, ResultType,
};
use serde_json::{json, Value};
use std::{
    collections::{HashMap, VecDeque},
    cell::RefCell,
    ffi::{CStr, CString},
    os::raw::c_char,
    sync::{Arc, Mutex, Once, OnceLock},
};
use uuid::Uuid;

// App-only, memory-only Tailnet routing. Never replace the user's configured proxy.
struct TailscaleRoute {
    proxy: config::Socks5Server,
    hosts: Vec<String>,
}
static TAILSCALE_ROUTE: OnceLock<Mutex<Option<TailscaleRoute>>> = OnceLock::new();

pub(crate) fn tailscale_proxy(peer: &str) -> Option<config::Socks5Server> {
    let host = if let Ok(address) = peer.parse::<std::net::SocketAddr>() {
        address.ip().to_string()
    } else if peer.parse::<std::net::IpAddr>().is_ok() {
        peer.to_owned()
    } else {
        peer.rsplit_once(':')
            .filter(|(_, port)| port.parse::<u16>().is_ok())
            .map(|(host, _)| host).unwrap_or(peer).trim_end_matches('.').to_ascii_lowercase()
    };
    let route = TAILSCALE_ROUTE.get()?.lock().unwrap();
    let route = route.as_ref()?;
    let tailnet_ip = match host.parse::<std::net::IpAddr>() {
        Ok(std::net::IpAddr::V4(ip)) => { let b = ip.octets(); b[0] == 100 && (64..128).contains(&b[1]) },
        Ok(std::net::IpAddr::V6(ip)) => ip.segments()[..3] == [0xfd7a, 0x115c, 0xa1e0],
        _ => false,
    };
    if tailnet_ip || host.ends_with(".ts.net") || route.hosts.contains(&host) {
        Some(route.proxy.clone())
    } else { None }
}

struct Frame {
    bytes: Box<[u8]>,
    width: usize,
    height: usize,
    display: usize,
}
#[derive(Default)]
struct Frontend {
    session: Option<Uuid>,
    events: VecDeque<Value>,
    frame: Option<Frame>,
}
static INITIALIZED: Once = Once::new();
static FRONTENDS: OnceLock<Mutex<HashMap<String, Arc<Mutex<Frontend>>>>> = OnceLock::new();
thread_local! { static WINDOW_CONTEXT: RefCell<String> = const { RefCell::new(String::new()) }; }
fn frontends() -> &'static Mutex<HashMap<String, Arc<Mutex<Frontend>>>> {
    FRONTENDS.get_or_init(Default::default)
}
fn frontend() -> Arc<Mutex<Frontend>> {
    let key = WINDOW_CONTEXT.with(|c| c.borrow().clone());
    frontends().lock().unwrap().entry(key).or_default().clone()
}
fn session_frontend(sid: &Uuid) -> Option<Arc<Mutex<Frontend>>> {
    let states: Vec<_> = frontends().lock().ok()?.values().cloned().collect();
    states.into_iter().find(|state| state.lock().map(|s| s.session == Some(*sid)).unwrap_or(false))
}
fn dispatch_window(request: Value) -> ResultType<Value> {
    let key = text(&request, "window");
    WINDOW_CONTEXT.with(|context| {
        let previous = context.replace(key);
        let result = dispatch(request);
        context.replace(previous);
        result
    })
}

// A connection can be cancelled before its I/O thread installs its sender.
// Existing Flutter sessions do not initialize this frontend and keep their path.
pub(crate) fn session_is_current<T: crate::ui_session_interface::InvokeUiSession>(
    handler: &crate::ui_session_interface::Session<T>,
) -> bool {
    if !INITIALIZED.is_completed() {
        return true;
    }
    let states: Vec<_> = match frontends().lock() {
        Ok(states) => states.values().cloned().collect(),
        Err(_) => return false,
    };
    states.into_iter().any(|state| {
        let sid = state.lock().ok().and_then(|s| s.session);
        sid.and_then(|sid| flutter::sessions::get_session_by_session_id(&sid))
            .is_some_and(|session| Arc::ptr_eq(&handler.sender, &session.sender))
    })
}

pub(crate) fn event(sid: &Uuid, event: &str) {
    let Some(frontend) = session_frontend(sid) else { return; };
    let Ok(mut state) = frontend.lock() else { return; };
    if state.session.as_ref() != Some(sid) {
        return;
    }
    if let Ok(mut value) = serde_json::from_str::<Value>(event) {
        if value["name"].as_str() == Some("msgbox") {
            value["sourceTitle"] = value["title"].clone();
            for key in ["title", "text"] {
                if let Some(text) = value[key].as_str() {
                    value[key] = json!(ffi::translate(text.to_owned(), "zh-cn".into()).0);
                }
            }
        }
        // Only cursor positions are replaceable; quality events contain partial updates.
        let name = value["name"].as_str().unwrap_or_default();
        if name == "cursor_position" {
            state
                .events
                .retain(|old| old["name"].as_str() != Some(name));
        }
        state.events.push_back(value);
    }
}

pub(crate) fn frame<'a>(
    ids: impl Iterator<Item = &'a Uuid>,
    display: usize,
    rgba: &scrap::ImageRgb,
) -> bool {
    let mut matched = false;
    for id in ids {
        let Some(frontend) = session_frontend(id) else { continue; };
        let Ok(mut state) = frontend.lock() else { continue; };
        matched = true;
        // Keep one pending frame per window; backgrounded UIs cannot grow a queue.
        if state.frame.is_none() {
            state.frame = Some(Frame {
                bytes: rgba.raw.clone().into_boxed_slice(),
                width: rgba.w,
                height: rgba.h,
                display,
            });
        }
    }
    matched
}

#[repr(C)]
pub struct NativeFrame {
    data: *mut u8,
    length: usize,
    width: usize,
    height: usize,
    display: usize,
}

/// The caller owns the returned bytes and releases them with rd_ios_free_bytes.
#[no_mangle]
pub unsafe extern "C" fn rd_ios_take_frame(out: *mut NativeFrame) -> bool {
    if out.is_null() {
        return false;
    }
    let frontend = frontend();
    let Ok(mut state) = frontend.lock() else { return false; };
    let Some(frame) = state.frame.take() else {
        return false;
    };
    let length = frame.bytes.len();
    *out = NativeFrame {
        data: Box::into_raw(frame.bytes) as *mut u8,
        length,
        width: frame.width,
        height: frame.height,
        display: frame.display,
    };
    true
}
#[no_mangle]
pub unsafe extern "C" fn rd_ios_take_window_frame(context: *const c_char, out: *mut NativeFrame) -> bool {
    if context.is_null() { return false; }
    let Ok(key) = CStr::from_ptr(context).to_str() else { return false; };
    WINDOW_CONTEXT.with(|value| {
        let previous = value.replace(key.to_owned());
        let result = rd_ios_take_frame(out);
        value.replace(previous);
        result
    })
}
#[no_mangle]
pub unsafe extern "C" fn rd_ios_free_bytes(data: *mut u8, length: usize) {
    if !data.is_null() {
        drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
            data, length,
        )));
    }
}
#[no_mangle]
pub unsafe extern "C" fn rd_ios_free_string(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}

#[no_mangle]
pub unsafe extern "C" fn rd_ios_request(request: *const c_char) -> *mut c_char {
    let result = if request.is_null() {
        Err(anyhow!("Empty request"))
    } else {
        CStr::from_ptr(request)
            .to_str()
            .map_err(|e| anyhow!(e.to_string()))
            .and_then(|s| serde_json::from_str::<Value>(s).map_err(Into::into))
            .and_then(dispatch_window)
    };
    let value = match result {
        Ok(v) => v,
        Err(e) => json!({"error": e.to_string()}),
    };
    match CString::new(value.to_string()) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

const LOCAL: &[&str] = &[
    "enable-tcp-punch",
    "enable-udp-punch",
    "enable-ipv6-punch",
    "enable-webrtc",
    "keep-awake-during-outgoing-sessions",
];
const GLOBAL: &[&str] = &["allow-websocket", "allow-insecure-tls-fallback"];
const DISPLAY: &[&str] = &[
    "view-style",
    "image-quality",
    "codec-preference",
    "custom_image_quality",
    "custom-fps",
];
const OTHER: &[(&str, &str)] = &[
    ("只读模式", "view-only"),
    ("显示远端指针", "show-remote-cursor"),
    ("跟随远端指针", "follow-remote-cursor"),
    ("跟随远端窗口焦点", "follow-remote-window"),
    ("显示画质监视器", "show-quality-monitor"),
    ("静音", "disable-audio"),
    ("禁用剪贴板", "disable-clipboard"),
    ("会话结束后锁屏", "lock-after-session-end"),
    ("隐私模式", "privacy-mode"),
    ("真彩色 4:4:4", "i444"),
    ("反转滚轮", "reverse-mouse-wheel"),
    ("交换左右键", "swap-left-right-mouse"),
];
fn local(key: &str) -> String {
    ffi::main_get_local_option(key.to_owned()).0
}
fn fixed(key: &str) -> bool {
    config::is_disable_settings() || ffi::main_is_option_fixed(key.to_owned()).0
}
const SESSION_TOGGLES: &[&str] = &["view-only", "show-remote-cursor", "disable-audio", "disable-clipboard", "lock-after-session-end", "reverse-mouse-wheel", "swap-left-right-mouse"];
fn session_settings() -> ResultType<Value> {
    let sid = session()?;
    let toggles: serde_json::Map<String, Value> = SESSION_TOGGLES.iter().map(|key| (key.to_string(), json!(ffi::session_get_toggle_option(sid, key.to_string()).unwrap_or(false)))).collect();
    Ok(json!({"sessionSettings": {
        "toggles": toggles,
        "quality": ffi::session_get_image_quality(sid).filter(|v| !v.is_empty()).unwrap_or_else(|| "balanced".into()),
        "codec": ffi::session_get_option(sid, "codec-preference".into()).filter(|v| !v.is_empty()).unwrap_or_else(|| "auto".into()),
        "codecs": serde_json::from_str::<Value>(&ffi::session_alternative_codecs(sid)).unwrap_or(json!({})),
        "custom": ffi::session_get_custom_image_quality(sid).unwrap_or_default()
    }}))
}

fn terminal_id(a: &Value) -> ResultType<i32> {
    match a.get("terminalId") {
        None => Ok(1),
        Some(value) => value.as_i64().filter(|id| *id > 0 && *id <= i32::MAX as i64)
            .map(|id| id as i32).ok_or_else(|| anyhow!("无效的终端标签")),
    }
}

fn text(v: &Value, key: &str) -> String {
    v[key].as_str().unwrap_or_default().to_owned()
}
fn flag(v: &Value, key: &str) -> bool {
    v[key].as_bool().unwrap_or(false)
}
fn session() -> ResultType<Uuid> {
    frontend()
        .lock()
        .map_err(|_| anyhow!("Session state unavailable"))?
        .session
        .ok_or_else(|| anyhow!("当前没有远程连接"))
}
fn allowed(sid: &Uuid) -> bool {
    flutter::sessions::get_session_by_session_id(sid).is_some_and(|s| {
        s.server_keyboard_enabled
            .read()
            .map(|v| *v)
            .unwrap_or(false)
            && s.lc.read().map(|v| !v.view_only.v).unwrap_or(false)
    })
}
fn shape(sid: Uuid, id: String) -> Value {
    match ffi::session_get_cursor_shape(sid, id) {
        Some(s) => {
            json!({"hotx":s.hotx,"hoty":s.hoty,"width":s.width,"height":s.height,"colors":crate::encode64(&s.colors)})
        }
        None => Value::Null,
    }
}
fn snapshot() -> Value {
    let peers: Value =
        serde_json::from_str(&ffi::main_load_recent_peers_for_ab("[]".into())).unwrap_or(json!([]));
    let favorites = ffi::main_get_fav();
    let peers: Vec<Value> = peers
        .as_array()
        .into_iter()
        .flatten()
        .map(|p| {
            let id = text(p, "id");
            let name = ["alias", "hostname", "id"]
                .iter()
                .map(|k| text(p, k))
                .find(|v| !v.is_empty())
                .unwrap_or_else(|| id.clone());
            json!({"favorite":favorites.contains(&id),"forceRelay":ffi::main_get_peer_option_sync(id.clone(), "force-always-relay".into()).0=="Y","hasPassword":ffi::main_peer_has_password(id.clone()),"id":id,"name":name,"username":p["username"],"hostname":p["hostname"],"platform":p["platform"]})
        })
        .collect();
    let settings: serde_json::Map<String, Value> = LOCAL
        .iter()
        .map(|k| (k.to_string(), json!(config::option2bool(k, &local(k)))))
        .chain(GLOBAL.iter().map(|k| {
            (
                k.to_string(),
                json!(config::option2bool(k, &ffi::main_get_option(k.to_string()))),
            )
        }))
        .collect();
    let defaults: serde_json::Map<String, Value> = DISPLAY
        .iter()
        .map(|k| {
            (
                k.to_string(),
                json!(ffi::main_get_user_default_option(k.to_string()).0),
            )
        })
        .collect();
    let fixed_keys: Vec<&str> = LOCAL
        .iter()
        .chain(GLOBAL)
        .chain(DISPLAY)
        .copied()
        .chain(["proxy-url"])
        .filter(|k| fixed(k))
        .collect();
    let servers: serde_json::Map<String, Value> = [
        "custom-rendezvous-server",
        "relay-server",
        "api-server",
        "key",
    ]
    .iter()
    .map(|k| (k.to_string(), json!(ffi::main_get_option(k.to_string()))))
    .collect();
    json!({"ready":true,"lastId":ffi::main_get_last_remote_id(),"peers":peers,"settings":settings,"defaults":defaults,"fixed":fixed_keys,
        "servers":servers,"cursorSize":local("ios-cursor-size").parse::<f64>().unwrap_or(28.0).clamp(16.0,64.0),
        "inputMode":if local("ios-direct-touch-mode")=="Y" {"touch-new"} else if local("touch-mode")=="Y" {"touch"} else if local("ios-trackpad-mode")=="Y" {"trackpad"} else {"mouse"},
        "otherDefaults":OTHER.iter().map(|(title,k)|json!({"title":title,"key":k,"value":ffi::main_get_user_default_option(k.to_string()).0=="Y","fixed":fixed(k)})).collect::<Vec<_>>(),
        "accountUser":local("user_info"),
        "codecs":serde_json::from_str::<Value>(&ffi::main_supported_hwdecodings().0).unwrap_or(json!({})),
        "hideNetwork":crate::get_builtin_option("hide-network-setting")=="Y","hideProxy":crate::get_builtin_option("hide-proxy-setting")=="Y"})
}
fn dispatch(request: Value) -> ResultType<Value> {
    let method = text(&request, "method");
    let a = &request["args"];
    match method.as_str() {
        "initialize" => {
            INITIALIZED.call_once(|| {
                ffi::main_get_data_dir_ios(text(a, "directory"));
                ffi::main_device_id(text(a, "deviceId"));
                ffi::main_device_name(text(a, "deviceName"));
                ffi::main_init(text(a, "directory"), String::new());
            });
            return Ok(snapshot());
        }
        "refresh" | "state" => return Ok(snapshot()),
        "accountInfo" => {
            return Ok(json!({
                "server":ffi::main_get_api_server(), "id":ffi::main_get_my_id(),
                "uuid":ffi::main_get_uuid(), "token":local("access_token"),
                "deviceInfo":serde_json::from_str::<Value>(&ffi::main_get_login_device_info().0).unwrap_or(json!({})),
                "enabled":!ffi::is_disable_account().0
            }))
        }
        "saveAccount" => {
            ffi::main_set_local_option("access_token".into(), text(a, "token"));
            ffi::main_set_local_option("user_info".into(), text(a, "user"));
        }
        "peerAction" => {
            let id = text(a, "id");
            if id.is_empty() {
                bail!("缺少设备 ID");
            }
            match text(a, "action").as_str() {
                "rename" => ffi::main_set_peer_alias(id, text(a, "value").trim().to_owned()),
                "forgetPassword" => ffi::main_forget_password(id),
                "remove" => ffi::main_remove_peer(id),
                "relay" => ffi::main_set_peer_option(
                    id,
                    "force-always-relay".into(),
                    if flag(a, "value") { "Y" } else { "" }.into(),
                ),
                "favorite" => {
                    let mut favorites = ffi::main_get_fav();
                    favorites.retain(|v| v != &id);
                    if flag(a, "value") {
                        favorites.push(id);
                    }
                    ffi::main_store_fav(favorites);
                }
                _ => bail!("未知设备操作"),
            }
        }
        "terminalOpen" => {
            ffi::session_open_terminal(
                session()?,
                terminal_id(a)?,
                a["rows"].as_u64().unwrap_or(24).clamp(1, 500) as u32,
                a["cols"].as_u64().unwrap_or(80).clamp(1, 500) as u32,
            );
            return Ok(Value::Null);
        }
        "terminalInput" => {
            ffi::session_send_terminal_input(session()?, terminal_id(a)?, text(a, "data"));
            return Ok(Value::Null);
        }
        "terminalResize" => {
            ffi::session_resize_terminal(
                session()?,
                terminal_id(a)?,
                a["rows"].as_u64().unwrap_or(24).clamp(1, 500) as u32,
                a["cols"].as_u64().unwrap_or(80).clamp(1, 500) as u32,
            );
            return Ok(Value::Null);
        }
        "terminalClose" => {
            ffi::session_close_terminal(session()?, terminal_id(a)?);
            return Ok(Value::Null);
        }
        "fileList" => {
            ffi::session_read_remote_dir(session()?, text(a, "path"), flag(a, "hidden"));
            return Ok(Value::Null);
        }
        "fileDelete" => {
            let sid = session()?;
            if !flag(a, "confirmed") { bail!("需要确认永久删除"); }
            if Uuid::parse_str(&text(a, "session"))? != sid { bail!("远程连接已变更"); }
            let path = text(a, "path");
            let normalized = path.replace('\\', "/");
            let parts: Vec<_> = normalized.split('/').filter(|part| !part.is_empty()).collect();
            if path.contains('\0') || parts.is_empty() || parts.iter().any(|part| *part == "." || *part == "..")
                || (parts.len() == 1 && parts[0].ends_with(':')) || (normalized.starts_with("//") && parts.len() <= 2) {
                bail!("禁止删除根目录或无效路径");
            }
            let permitted = flutter::sessions::get_session_by_session_id(&sid).is_some_and(|s|
                s.server_file_transfer_enabled.read().map(|v| *v).unwrap_or(false)
                    && s.lc.read().map(|v| !v.view_only.v).unwrap_or(false));
            if !permitted { bail!("远端未授权文件操作"); }
            let job = a["job"].as_i64().filter(|id| *id > 0 && *id <= i32::MAX as i64).ok_or_else(|| anyhow!("无效的任务编号"))? as i32;
            match text(a, "operation").as_str() {
                "list" => ffi::session_read_dir_to_remove_recursive(sid, job, path, true, true),
                "file" => ffi::session_remove_file(sid, job, path, a["file"].as_i64().unwrap_or(0).clamp(0, i32::MAX as i64) as i32, true),
                "emptyDirectories" => ffi::session_remove_all_empty_dirs(sid, job, path, true),
                _ => bail!("无效的文件删除操作"),
            }
            return Ok(Value::Null);
        }
        "fileTransfer" => {
            if flag(a, "download") && flag(a, "directory") {
                ffi::session_read_remote_empty_dirs_recursive_sync(session()?, text(a, "from"), flag(a, "hidden"));
            }
            ffi::session_send_files(
                session()?,
                a["job"].as_i64().unwrap_or(1) as i32,
                text(a, "from"),
                text(a, "to"),
                0,
                flag(a, "hidden"),
                flag(a, "download"),
                flag(a, "directory"),
            );
            return Ok(Value::Null);
        }
        "fileCancel" => {
            ffi::session_cancel_job(session()?, a["job"].as_i64().unwrap_or(1) as i32);
            return Ok(Value::Null);
        }
        "fileOverride" => {
            ffi::session_set_confirm_override_file(
                session()?,
                a["job"].as_i64().unwrap_or(1) as i32,
                a["file"].as_i64().unwrap_or(0) as i32,
                flag(a, "replace"),
                false,
                flag(a, "upload"),
            );
            return Ok(Value::Null);
        }
        "connect" => {
            if frontend()
                .lock()
                .map_err(|_| anyhow!("Session state unavailable"))?
                .session
                .is_some()
            {
                bail!("请先结束当前连接");
            }
            let id = text(a, "id").trim().to_owned();
            if id.is_empty() {
                bail!("请输入远端 ID 或 IP 地址");
            }
            let sid = Uuid::new_v4();
            let result = ffi::session_add_sync(
                sid,
                id.clone(),
                text(a, "mode") == "files",
                text(a, "mode") == "camera",
                false,
                false,
                text(a, "mode") == "terminal",
                String::new(),
                flag(a, "forceRelay"),
                text(a, "password"),
                false,
                None,
                text(a, "loginMethod"),
            )
            .0;
            if !result.is_empty() {
                bail!("{}", result);
            }
            {
                let frontend = frontend();
                let mut state = frontend
                    .lock()
                    .map_err(|_| anyhow!("Session state unavailable"))?;
                state.session = Some(sid);
                state.events.clear();
                state.frame = None;
            }
            if let Err(e) = flutter::native_start(sid) {
                ffi::session_close(sid);
                if let Ok(mut s) = frontend().lock() {
                    s.session = None;
                }
                return Err(e);
            }
            return Ok(json!({"session":sid.to_string()}));
        }
        "releaseWindow" => {
            let sid = frontend().lock().map_err(|_| anyhow!("Session state unavailable"))?.session.take();
            if let Some(sid) = sid { ffi::session_close(sid); }
            let key = WINDOW_CONTEXT.with(|c| c.borrow().clone());
            frontends().lock().map_err(|_| anyhow!("Window state unavailable"))?.remove(&key);
            return Ok(Value::Null);
        }
        "disconnect" => {
            let sid = {
                let frontend = frontend();
                let mut s = frontend
                    .lock()
                    .map_err(|_| anyhow!("Session state unavailable"))?;
                s.events.clear();
                s.frame = None;
                s.session.take()
            };
            if let Some(sid) = sid {
                ffi::session_close(sid);
            }
            return Ok(snapshot());
        }
        "poll" => {
            let frontend = frontend();
            let mut s = frontend
                .lock()
                .map_err(|_| anyhow!("Session state unavailable"))?;
            let events: Vec<Value> = s.events.drain(..).collect();
            return Ok(json!({"session":s.session.map(|s|s.to_string()),"events":events}));
        }
        "cursor" => return Ok(shape(session()?, text(a, "id"))),
        "mouse" => {
            let sid = session()?;
            if allowed(&sid) {
                ffi::session_send_mouse(sid, a["message"].to_string());
            }
            return Ok(Value::Null);
        }
        "key" => {
            let sid = session()?;
            if allowed(&sid) {
                ffi::session_input_key(
                    sid,
                    text(a, "value"),
                    false,
                    true,
                    flag(a, "alt"),
                    flag(a, "ctrl"),
                    flag(a, "shift"),
                    flag(a, "command"),
                );
            }
            return Ok(Value::Null);
        }
        "text" => {
            let sid = session()?;
            if allowed(&sid) {
                ffi::session_input_string(sid, text(a, "value"));
            }
            return Ok(Value::Null);
        }
        "login" => {
            ffi::session_login(
                session()?,
                text(a, "username"),
                text(a, "osPassword"),
                text(a, "password"),
                flag(a, "remember"),
            );
            return Ok(Value::Null);
        }
        "twoFactor" => {
            ffi::session_send2fa(session()?, text(a, "code"), flag(a, "trust"));
            return Ok(Value::Null);
        }
        "insecure" => {
            ffi::session_set_common(
                session()?,
                "continue-insecure-connection".into(),
                if flag(a, "continue") { "Y" } else { "N" }.into(),
            );
            return Ok(Value::Null);
        }
        "reconnect" => {
            ffi::session_reconnect(session()?, flag(a, "forceRelay"));
            return Ok(Value::Null);
        }
        "resolution" => {
            let sid = session()?;
            if let Some(expected) = a["session"].as_str() {
                if Uuid::parse_str(expected)? != sid { bail!("远程连接已变更"); }
            }
            if !allowed(&sid) { bail!("远端未允许修改分辨率"); }
            let width = a["width"].as_i64().filter(|v| (64..=8192).contains(v)).ok_or_else(|| anyhow!("无效的分辨率宽度"))?;
            let height = a["height"].as_i64().filter(|v| (64..=8192).contains(v)).ok_or_else(|| anyhow!("无效的分辨率高度"))?;
            let display = a["display"].as_i64().filter(|v| *v >= 0 && *v <= i32::MAX as i64).ok_or_else(|| anyhow!("无效的显示器"))?;
            ffi::session_change_resolution(sid, display as i32, width as i32, height as i32);
            return Ok(Value::Null);
        }
        "display" => {
            if let Some(s) = flutter::sessions::get_session_by_session_id(&session()?) {
                s.switch_display(a["index"].as_i64().unwrap_or(0) as i32);
            }
            return Ok(Value::Null);
        }
        "inputMode" => {
            let mode = text(a, "value");
            if !["mouse", "trackpad", "touch", "touch-new"].contains(&mode.as_str()) {
                bail!("无效的输入模式");
            }
            ffi::main_set_local_option(
                "touch-mode".into(),
                if mode == "touch" || mode == "touch-new" { "Y" } else { "N" }.into(),
            );
            ffi::main_set_local_option(
                "ios-direct-touch-mode".into(),
                if mode == "touch-new" { "Y" } else { "N" }.into(),
            );
            ffi::main_set_local_option(
                "ios-trackpad-mode".into(),
                if mode == "trackpad" { "Y" } else { "N" }.into(),
            );
        }
        "cursorSize" => {
            let size = a["value"]
                .as_f64()
                .filter(|v| v.is_finite())
                .ok_or_else(|| anyhow!("无效的指针大小"))?
                .clamp(16.0, 64.0);
            ffi::main_set_local_option("ios-cursor-size".into(), size.to_string());
        }
        "saveServers" => {
            for k in [
                "custom-rendezvous-server",
                "relay-server",
                "api-server",
                "key",
            ] {
                if fixed(k) {
                    bail!("设置由管理员固定");
                }
                ffi::main_set_option(k.into(), text(a, k).trim().to_owned())?;
            }
        }
        "tailscaleRoute" => {
            let mut route = TAILSCALE_ROUTE.get_or_init(Default::default).lock().unwrap();
            let address = text(a, "address");
            if address.is_empty() { *route = None; }
            else {
                let socket: std::net::SocketAddr = address.parse()?;
                if !socket.ip().is_loopback() || socket.port() == 0 { bail!("Tailnet proxy must be loopback"); }
                let password = text(a, "password");
                if password.is_empty() { bail!("Tailnet proxy authentication is required"); }
                *route = Some(TailscaleRoute {
                    proxy: config::Socks5Server { proxy: format!("socks5://{}", socket), username: text(a, "username"), password },
                    hosts: a["hosts"].as_array().map(|hosts| hosts.iter().filter_map(Value::as_str)
                        .map(|host| host.trim_end_matches('.').to_ascii_lowercase()).collect()).unwrap_or_default(),
                });
            }
            return Ok(Value::Null);
        }
        "loadProxy" => return Ok(json!({"proxy":ffi::main_get_socks()})),
        "saveProxy" => {
            if fixed("proxy-url") {
                bail!("代理设置由管理员固定");
            }
            let proxy = text(a, "proxy");
            if !proxy.is_empty() {
                let error = ffi::main_test_if_valid_server(
                    proxy.split("://").last().unwrap_or_default().into(),
                    false,
                );
                if !error.is_empty() {
                    bail!("{}", error);
                }
            }
            ffi::main_set_socks(proxy, text(a, "username"), text(a, "password"));
        }
        "osPasswordSettings" => {
            let sid = session()?;
            return Ok(json!({"session": sid.to_string(),
                "password": ffi::session_get_peer_option(sid, "os-password".into()),
                "autoLogin": !ffi::session_get_peer_option(sid, "auto-login".into()).is_empty(),
                "canSend": allowed(&sid),
                "editable": !fixed("os-password") && !fixed("auto-login")}));
        }
        "saveOSPassword" => {
            let sid = session()?;
            if Uuid::parse_str(&text(a, "session"))? != sid { bail!("远程连接已变更"); }
            if fixed("os-password") || fixed("auto-login") { bail!("设置由管理员固定"); }
            let password = text(a, "password");
            if flag(a, "send") && (!allowed(&sid) || password.is_empty()) { bail!("当前无法发送操作系统密码"); }
            ffi::session_peer_option(sid, "os-password".into(), password.clone());
            if a["autoLogin"].is_boolean() {
                ffi::session_peer_option(sid, "auto-login".into(), if flag(a, "autoLogin") { "Y".into() } else { "".into() });
            }
            if flag(a, "send") { ffi::session_input_os_password(sid, password); }
        }
        "sessionSettings" => return session_settings(),
        "sessionOption" => {
            let sid = session()?;
            let key = text(a, "key");
            if fixed(&key) { bail!("设置由管理员固定"); }
            match key.as_str() {
                "image-quality" => {
                    let value = text(a, "value");
                    if !["best", "balanced", "low", "custom"].contains(&value.as_str()) { bail!("无效的画质"); }
                    ffi::session_set_image_quality(sid, value);
                }
                "codec-preference" => {
                    let value = text(a, "value");
                    let codecs: Value = serde_json::from_str(&ffi::session_alternative_codecs(sid)).unwrap_or(json!({}));
                    if value != "auto" && value != "vp9" && codecs[&value] != true { bail!("当前连接不支持此编码"); }
                    ffi::session_peer_option(sid, key, value);
                    ffi::session_change_prefer_codec(sid);
                }
                "custom_image_quality" => ffi::session_set_custom_image_quality(sid, a["value"].as_i64().unwrap_or(50).clamp(10,100) as i32),
                "custom-fps" => ffi::session_set_custom_fps(sid, a["value"].as_i64().unwrap_or(30).clamp(5,120) as i32),
                _ if SESSION_TOGGLES.contains(&key.as_str()) => {
                    if ffi::session_get_toggle_option(sid, key.clone()).unwrap_or(false) != flag(a, "value") { ffi::session_toggle_option(sid, key); }
                }
                _ => bail!("不支持此会话设置"),
            }
            return session_settings();
        }
        "setting" => {
            let key = text(a, "key");
            if fixed(&key) {
                bail!("设置由管理员固定");
            }
            let value = if a["value"].is_boolean() {
                if flag(a, "value") {
                    "Y".into()
                } else {
                    "N".into()
                }
            } else {
                text(a, "value")
            };
            if LOCAL.contains(&key.as_str()) {
                ffi::main_set_local_option(key, value);
            } else if GLOBAL.contains(&key.as_str()) {
                ffi::main_set_option(key, value)?;
            } else if DISPLAY.contains(&key.as_str()) || OTHER.iter().any(|(_, k)| *k == key) {
                ffi::main_set_user_default_option(key, value);
            } else {
                bail!("不支持此设置");
            }
        }
        _ => bail!("不支持此操作：{}", method),
    }
    Ok(snapshot())
}
