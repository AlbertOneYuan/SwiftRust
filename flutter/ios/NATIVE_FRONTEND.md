# Native iOS frontend

The iOS application is a SwiftUI/UIKit client of the existing Rust session engine.
It does not instantiate a Flutter engine or view controller, execute Dart, or package
Flutter.framework, App.framework, Flutter assets, or Flutter plugins. Android and the
other Flutter clients keep their existing frontend paths.

## Ownership and rendering

- SceneDelegate owns one NativeShellModel and a UIHostingController.
- NativeRustBridge.h is the narrow, hand-written C ABI. NativeRustCore.swift owns
  JSON response strings and transfers video buffer ownership to CGDataProvider.
- src/platform/ios_native.rs owns the native session registration, event queue and
  one pending frame. A slow or backgrounded renderer drops frames instead of
  growing a frame queue. Session UUID checks reject events from closed sessions.
- NativeRemoteCanvas.swift presents decoded BGRA frames with CALayer. Input,
  viewport transforms, original cursor shapes, fixed cursor size, pinch, two finger
  scroll, long press drag, keyboard input and cancellation run in Swift/UIKit.
- Credentials, two-factor prompts, encryption warnings, errors and disconnect
  confirmation are native SwiftUI. Encryption warnings require an explicit user
  choice; the native frontend does not bypass them.
- Existing configuration, recent peers and server settings stay in Documents,
  matching the previous iOS client. The saved cursor size is ios-cursor-size.

The Rust Cargo feature is still named `flutter`, because it enables shared session
and configuration entry points. That feature name does not imply a Flutter iOS
runtime. Matching generated Rust bridge sources remain a prerequisite of that
shared Rust build; do not run bridge code generation for this frontend.

## Build and verification

Minimum iOS version: 17. Native.xcconfig selects the Rust static library. Build the
Rust core for aarch64-apple-ios (release) or aarch64-apple-ios-sim (debug), with the
same native codec dependencies as the upstream client. RUSTDESK_LIBRARY_DIR can be
overridden for a local device debug library. The Runner project builds with Xcode
without a Flutter SDK, CocoaPods installation or Flutter build scripts.

Run scheme Runner with xcodebuild, or run its NativeFrontendTests and
NativeFrontendUITests test targets. The tests cover native-only controllers and
loaded frameworks, cursor data validation, rendering/zoom/pointer sizing, early
server cursor position, connection cleanup, three repeated connect/disconnect
cycles and returning from the background. The UI test uses an unavailable local
endpoint and never accepts an unverified encryption connection.

## Existing paths changed

- AppDelegate.swift, SceneDelegate.swift, Info.plist and Main.storyboard: replace
  the Flutter launch/window path, including the storyboard fallback.
- Runner-Bridging-Header.h, Runner.xcodeproj, Runner.xcworkspace and Runner.xcscheme: link the native
  C ABI and system frameworks, remove Flutter/plugin build/embed phases, add tests.
- src/flutter.rs: iOS-only hooks for native events, cursor notifications and frames;
  plus the parallel native session start entry. Unregistered Flutter clients retain
  their original delivery path.
- src/ui_session_interface.rs: an iOS-only startup check prevents an already
  cancelled native session from starting after its sender is installed. It returns
  the original behavior when the native frontend has not initialized.
- src/platform/mod.rs: declares the iOS-only adapter module.

The temporary Dart navigation bridge was removed. Shared protocol/API signatures,
submodule revisions and non-iOS behavior were not changed for this migration.

The session now uses NativeImmersiveSessionView outside the home navigation stack.
NativeHostingController hides the status bar and home indicator during a session;
the canvas extends to all screen edges. Material-backed controls sit in a vertical rail on the right, in both folded
and expanded layouts, avoiding camera occlusion using reserved regions on Duo. No camera
ring button is shown. The remote keyboard spans the entire window in both
orientations, with its material background restored and only its keys inset where
a side camera overlaps. Pinch zoom remains; zoom buttons and session title/bottom
bars have been removed. The home uses the native TabView with Home, Favorites and Settings. There is no
Search tab. The home has no search bar; the minimal UIKit device search remains on Favorites. The home navigation bar is hidden and login remains in the
connection card, controlled by the existing Settings visibility switch. The
connection card has a compact header, ID field, disclosure options and an outline
Connect button. All interface icons use regular-weight Apple SF Symbols, matching Settings.
Tab symbols are monochrome SF Symbols rendered at device
scale so UIKit cannot substitute filled variants. Remote controls also use black
regular-weight symbols. Regression coverage checks search/card alignment, tab switching,
login visibility, right-side controls and full-window keyboard layouts.


Connection warnings and reconnect confirmations use Continue as their default
action. The user may explicitly remember Continue for that remote device and
prompt category; password and two-factor challenges remain interactive.

NativeAccountView restores account login in the connection card and in Settings. The
home entry can be hidden through AppStorage without removing the Settings entry.
It uses the existing account API request format, supports password/email/TFA
challenges and stores the resulting token/user through existing Rust local options.
The API server and device identifiers come from Rust; passwords are not persisted.

Third-party icon assets and their icon-specific license screen/resource were removed. The device ID field now reads “远程 ID”.

Device menus and native sessions
-------------------------------
NativeDeviceSessions.swift adds an ellipsis menu and long-press menu to saved
devices. Connection modes are Remote Control, Files, Camera and Terminal; each
can request approval. Peer actions persist alias, relay, favorites and forgotten
passwords through existing Rust configuration APIs. Record deletion requires a
confirmation. The home connection-options disclosure was removed; top spacing
now matches the 20-point visible left margin.

The terminal uses SwiftTerm 1.18.0, pinned through Swift Package Manager (license
included as SwiftTermLicense.txt). A real VT100/ANSI emulator is necessary for
cursor motion, colors, Unicode and full-screen terminal programs; a plain text
log would not implement the protocol. Rust provides terminal opened/data/closed/
error events, and receives input and geometry through existing terminal APIs.
The UI provides an output canvas, session status, explicit copy/paste, keyboard,
font controls, Esc/Tab/Ctrl-C/Ctrl-D and arrow keys. Remote clipboard reads/writes
and automatic external-link opening are not enabled by the emulator delegate.

The file screen lists remote directories and supports individual file uploads
from the document picker and downloads to Documents/Downloads. Downloads can be
shared or saved using the system share sheet. Incoming overwrite requests require
explicit confirmation, and transfers can be cancelled. Directory transfer and
remote filesystem deletion are not exposed by this initial native file browser.
Camera sessions reuse the native video canvas with input disabled. Existing
non-iOS and Flutter session paths retain their original defaults.

Build note: SwiftTerm's renderer requires the Xcode Metal Toolchain. If missing,
install it with `xcodebuild -downloadComponent MetalToolchain` before building.

Validation limits: ANSI/UTF-8 parsing, device menus, terminal layout and session
exit are covered by native tests. The real simulator connection stopped at the
existing end-to-end encryption confirmation; no remote shell command or live
file transfer was executed. On iOS 27, XCTest also records a SwiftUI publishing
warning while dismissing the existing global disconnect confirmation. The home
return assertions pass; restructuring that shared presentation flow is outside
this device-menu/terminal change.

Appearance review
-----------------
UI chrome uses semantic primary/secondary and UIKit label colors. SF tab images
retain their outline masks but use template rendering so tint follows appearance.
Connect disabled state, peer/menu icons, remote controls, search
icons/keyboard and authentication placeholders now adapt to light/dark themes.
Switches and enabled keyboard modifiers use system green; connection highlights
use RustDesk accent blue (#0071FF). The connect card uses blue/white controls and
a larger rounded numeric ID font;
terminal disabled shortcut labels use explicit secondary text. The terminal output
surface remains black and preserves the remote ANSI palette. Dark UI regression
coverage captures Home, device menu, Settings, account, help, advanced options,
files, terminal, remote controls and the remote keyboard with explicit app-level
dark preference, alongside the light-mode home/navigation test.

Connection prompt correction
----------------------------
Native message boxes now honor the core hasRetry flag; success and progress events
do not reconnect. Saved reconnect consent permits one automatic retry per session,
then shows the error and lets the user choose. Nonretryable messages acknowledge
without clearing video or starting another connection. Unchecking a prompt writes
false, and Settings > Connection > Connection prompts exposes saved per-peer
choices so either can be revoked. These changes affect only NativeRustCore.swift,
NativeShellModel.swift and native prompt/settings rendering; Rust and Flutter
connection paths are unchanged.

The home QR action uses Apple's VisionKit scanner with camera permission and an
unsupported-device fallback. It accepts numeric remote IDs and rustdesk:// links
carrying numeric IDs, then requires an explicit Connect tap. It does not import
server configuration, credentials or arbitrary web links. Camera scanning requires
a physical device; parser and navigation are covered on Simulator.

UI regression surface: NativeShellView.swift changes the home card, app accent
and adds the QR sheet; NativeSettingsView.swift changes switch/modifier colors
and prompt preference controls; NativeImmersiveSessionView.swift colors enabled
remote keyboard controls green. NativeRustCore.swift carries the existing core
retry flag, and NativeShellModel.swift uses it when deciding whether to reconnect.
These paths are native iOS only. Nine native unit/UI tests passed; final dark
connect-button text was also checked visually after setting explicit white color.

Settings and gesture help follow-up
-----------------------------------
NativeSettingsView.swift adds SF Symbols for pointer and appearance rows, and
shows mode-specific help matching NativeRemoteCanvas input behavior. Help opens
on the current mode and permits browsing all three modes without changing input.
NativeShellView.swift uses the rounded title2 numeric ID font for connection
input. NativeDeviceSessions.swift uses the same rounded numeric family for history
and favorites while retaining their original subheadline size. Gesture
illustrations distinguish single/double taps and two-finger actions with badges.
No session or gesture runtime behavior changes in this UI follow-up.

Original gestures and fourth input mode
---------------------------------------
Mouse and touch help now follows the original RustDesk gesture_help.dart: long
press is right click, mouse drag is double-tap then move, direct-touch drag is
one-finger movement, three fingers scroll vertically, and two fingers pan/zoom
the canvas. NativeRemoteCanvas.swift restores those mappings for mouse/touch;
trackpad keeps its existing two-finger scroll and long-press drag.

The fourth mode, touch-new (新直接触控), preserves direct positioning, one-finger
drag and long-press right click, with two-finger scrolling/pinch zoom and
three-finger canvas panning. NativeSettingsView.swift and
NativeImmersiveSessionView.swift expose the choice and matching help;
NativeShellView.swift uses the direct-touch symbol for both touch modes.
NativeShellModel.swift releases held input when switching modes. The iOS-only
adapter src/platform/ios_native.rs persists a separate ios-direct-touch-mode flag
without changing the shared Flutter or other-platform gesture implementation.

Device appearance follow-up
----------------------------
NativeSettingsView.swift places touch-new second in Settings and gesture help,
and NativeImmersiveSessionView.swift uses the same order for remote controls.
NativePeerBadge renders a gray rounded tile in NativeDeviceSessions.swift's shared
history/favorites row. Settings > Appearance > Device icons and colors exposes
per-device SF Symbol choices and icon colors, a system/device symbol catalog,
a live preview and restore-default action. AppStorage keeps these local UI
preferences keyed by peer ID; both card lists observe the same keys. Runtime
connection, gesture mappings, Rust/Flutter code and ID font sizes are unchanged.

Dock and favorite visual adjustment: NativeShellView.swift renders 28-point SF
Symbol masks in a 30-point tab image with medium weight; NativeDeviceSessions.swift
uses a yellow filled star for favorite cards. Only native tab/card rendering changes.

NativeDeviceSessions.swift renders the card options button in semantic secondary
gray, adapting the requested gray tint to both light and dark appearance.

Fullscreen relative input
-------------------------
NativeImmersiveSessionView.swift explicitly gives the UIKit canvas the full
available size and rectangular hit region, including transparent letterbox margins.
NativeSettingsView.swift documents that mouse/trackpad relative input accepts
those margins. Native canvas hit testing is checked through the actual hosting
window in portrait/landscape for both modes, away from interactive controls.
The underlying relative movement already accepts coordinates outside the video;
its speed, clamp and direct-touch mappings are retained.

Terminal shortcut glass
-----------------------
NativeDeviceSessions.swift renders the shared bottom/above-keyboard shortcut row
with individual regular system-material surfaces matching the header and adaptive
label colors. Disabled keys retain reduced opacity; the former full-width
backplate is removed. The same shortcut view is used at the bottom and as the terminal UIKit
inputAccessoryView, so the keyboard has a genuine system-managed accessory row.
Terminal first-responder state hides the bottom copy while the accessory is shown. Only terminal layout/styling changes;
terminal input actions and the desktop remote-keyboard UI retain their behavior.

Compact terminal shortcuts: NativeDeviceSessions.swift uses static material
surfaces and reduces both bottom/accessory rows from 56 to 40 points, using
28-point buttons and six-point vertical padding. Only terminal shortcut styling
and accessory height change; input actions and keyboard switching are retained.

Native terminal tabs and full-width output
------------------------------------------
NativeDeviceSessions.swift adds independent numbered terminal models and tab
selection, creation, long-press rename and close-current actions. Inactive tab
renderers stay mounted so ANSI state and scrollback survive switching. Each tab
owns its terminal protocol ID; src/platform/ios_native.rs passes that validated ID
through the four existing terminal FFI functions instead of hardcoding 1.
NativeShellModel.swift retains one tab collection per connection and resets it on
connection replacement/end. Shared Rust/Flutter terminal behavior is unchanged.

The terminal header replaces the host name with tabs, plus and a plain gear.
Header and shortcut controls use regular system material and adaptive text colors,
with no interactive scaling. NativeImmersiveSessionView.swift makes its existing
camera geometry helper available to the terminal; header top padding respects
camera lower edge and safe area. The output ignores horizontal container safe
areas, and the UIKit terminal disables automatic scroll-view insets to use the
full screen width. Only header controls reserve horizontal camera-safe space.

Initial terminal size correction
--------------------------------
NativeDeviceSessions.swift defers PTY opening until the tab's mounted terminal
view has nonzero bounds and has calculated its actual grid. The resize and SwiftUI geometry callbacks
complete deferred opening, including when the grid equals the defaults.
An opened acknowledgement also sends the latest grid to cover layout/keyboard
changes during the request. Failed or closed shells clear the pending request.
This removes the default-80-column startup race; shell output, including genuine
zsh partial-line markers, is not filtered and remote shell settings are untouched.
Only native terminal startup/resize timing changes; no Rust/Flutter changes.

Central disconnect confirmation
-------------------------------
NativeShellView.swift uses a shared centered alert for manual disconnects on
remote desktop, camera, terminal and file screens. The same modifier is attached
to the current sheet so authentication-prompt disconnects can confirm above it;
only the active presentation surface displays the alert. NativeImmersiveSessionView
and NativeSettingsView route connection cancellation/prompt disconnect through
that confirmation. NativeShellModel.closeSession clears its presentation flag.
Only manual disconnect presentation changes; remote session/error processing and
cleanup keep their existing behavior.

Bottom session dock and integrated options
------------------------------------------
NativeImmersiveSessionView.swift replaces the vertical rail with three compact
controls (system keyboard, shortcut keyboard, session settings) in a rectangular
strip touching the bottom edge. Horizontal dragging clamps to the screen and
snaps within 32 points of either side. A normalized position survives orientation
and keyboard-mode changes; no drag animation/scale is added. The existing canvas
and empty-space input stay behind the dock.

NativeSettingsView.swift adds a native session sheet with disconnect confirmation,
input modes, pointer options, display switching, fit/original scale, canvas lock,
quality/custom quality/FPS, supported codecs, read-only, clipboard, audio and lock
on session end. NativeShellView.swift presents it with the same centered disconnect
confirmation; NativeShellModel.swift tracks active session option values.
src/platform/ios_native.rs adds validated current-session getters/setters using the
existing FFI, rather than changing future-connection defaults. NativeRemoteCanvas
uses those current-session cursor/wheel/button settings. Other-platform and Flutter
UI paths remain unchanged. No microphone/voice-call feature is introduced.

Saved connection-error suppression and authentication identity
--------------------------------------------------------------
NativeShellModel.swift separates suppressing error dialogs from the single
per-session automatic retry. Saved consent suppresses subsequent retryable and
nonretryable Connection Error sheets while retaining failure status and a manual
retry action where the core permits retry. No repeated automatic reconnect loop
is introduced. NativeSettingsView.swift persists connection-error toggle changes
immediately and lets users revoke them; insecure consent still requires Continue.
Authentication/2FA prompts are excluded from connection-error suppression.

src/platform/ios_native.rs preserves the untranslated source title for reliable
error classification and returns cached peer username/hostname fields.
NativeShellModel combines cached/live peer information as username@hostname;
NativeSettingsView uses it next to the authentication lock. For an unknown peer
without a known username/hostname, its real remote ID remains the fallback.
NativeImmersiveSessionView shows a stopped error state instead of an endless
loading spinner; session settings and the terminal menu offer manual reconnect.

Compact system-menu dock and keyboard positioning
------------------------------------------------
NativeImmersiveSessionView.swift uses one 110×34 point three-icon control bar.
A transparent UIKit container anchors it eight points above keyboardLayoutGuide:
it clears the bottom safe area when closed and follows system/third-party
keyboards when open. No duplicate input-accessory bar or keyboard visibility
state is needed. The container passes touches outside the actual bar through to
the full-screen remote canvas. A UIKit pan recognizer observes only touches
starting inside the bar and cancels button taps once dragging starts; stationary
touches retain native Menu behavior. Horizontal dragging snaps to either side.
The position is shared in NativeShellModel so keyboard changes and rotation
preserve it. Closing a session resigns the input view before removal.

NativeSessionMenuContents in NativeSettingsView.swift provides the system's
translucent contextual-menu treatment, separate 控制模式 and 显示画面
submenus, quality/audio options and centered disconnect confirmation. The
全部会话设置 entry is removed. No microphone icon is added.
Regression coverage checks bottom clearance, both snap directions, keyboard
placement, contextual settings and letterbox canvas touch delivery. Rust and
other-platform paths do not change in this follow-up.

Keyboard-following canvas and full-screen relative input
-------------------------------------------------------
NativeImmersiveSessionView.swift now explicitly routes touches outside the dock
back to NativeCanvasView for connected mouse/trackpad sessions, including empty
letterbox margins. The same transparent input-routing container remains mounted
while the shortcut keyboard is open; its controls are hidden, and the keyboard
keeps priority over touches inside its own panel. Other input modes retain their
existing hit-testing path.

NativeRemoteCanvas.swift applies a separate keyboard lift to video and cursor
positions without changing their scale or the user's pan/zoom. The dock's UIKit
keyboardLayoutGuide supplies system-keyboard overlap; the existing shortcut
keyboard reports its measured height. Closing either restores the lift to zero.
Zoom anchor math and relative-pointer edge following include the lift so input
still targets the displayed desktop. This changes only native iOS canvas layout
and touch routing; remote protocol, Rust, terminal and file-transfer paths are
unchanged. Regression checks exercise a real system keyboard, equal video/cursor
movement, unchanged sizes, restoration and portrait/landscape margin hit-testing.

Reconnect status surface
------------------------
NativeImmersiveSessionView.swift gives the existing centered connection-failure
status a 270-point regular-material card with a 14-point corner radius and dim
backdrop, matching the native disconnect alert's background treatment. The
waiting spinner remains unboxed. This is presentation-only: reconnect commands,
saved prompt suppression and disconnect confirmation are unchanged.

Keyboard toggle icon
--------------------
NativeImmersiveSessionView.swift derives the dock icon from the same UIKit
keyboard overlap used for positioning: keyboard when closed, and
keyboard.chevron.compact.down when open, with matching accessibility labels.
Only the dock's presentation changes; existing input actions are retained. The
existing immersive keyboard UI check verifies both labels across a toggle.

Gestures originating outside the desktop image
---------------------------------------------
NativeImmersiveSessionView.swift enables multiple touches on the transparent
dock container and explicitly forwards non-control touches in all four input
modes, extending the previous mouse/trackpad-only path. NativeRemoteCanvas.swift
keeps existing mode-specific scrolling, panning and drag gestures. For pinch
centers in a black margin, zoom now anchors to the visible desktop's center;
pinching within the image retains its original finger anchor. The visible area
excludes keyboard overlap. This prevents black-margin pinch from pushing the
desktop away. Tests cover hit-testing in portrait/landscape for all modes and
black-margin zoom in/out while preserving the original in-image anchor behavior.
Only native iOS touch routing and zoom anchoring change; Rust, keyboard actions,
terminal and file-transfer paths are untouched.

Combined two-finger canvas transform
------------------------------------
NativeRemoteCanvas.swift no longer permanently locks trackpad/new-direct-touch
pairs to scrolling after their initial movement. A six-percent finger-distance
change promotes the pair to canvas transformation until lifted. Pairs beginning
entirely in the desktop's letterbox margins enter canvas transformation directly.
Zoom uses the preceding finger center, then applies the center's translation, so
scaling and canvas dragging occur together. Existing in-image parallel scrolling
and the canvas-lock option remain effective. NativeSettingsView.swift updates the
gesture description accordingly. A frame-based regression check covers combined
scale/translation, subsequent panning, and the locked-canvas case; no remote input
or Rust protocol paths change.

Keyboard edge alignment
------------------------
NativeRemoteCanvas.swift separates keyboard occlusion height from video
translation. On keyboard appearance/height changes, the displayed desktop's
bottom edge aligns exactly with the keyboard top, preserving current scale and
stored canvas pan. Fit/original-size actions also realign while a keyboard is
open. Closing restores zero presentation offset. Viewport bounds still use real
keyboard occlusion; zoom anchor math uses the separate presentation offset.
Only native canvas positioning changes. Regression checks cover a real system
keyboard, multiple zoom/keyboard sizes, equal pointer translation and restoration.

Native black-margin input ownership
----------------------------------
NativeRemoteCanvas.swift now owns an opaque black, full-screen NativeCanvasView
and embeds NativeDockArea directly inside that UIView. NativeImmersiveSessionView.swift
removes the sibling full-screen SwiftUI dock representable and its cross-sibling
hit-test forwarding. NativeDockArea returns hits only inside its visible bar;
all other touches fall naturally to its native canvas parent, including multiple
fingers in black margins. The existing mouse/pinch handlers therefore receive
image and margin touches through the same UIKit path. The existing accessibility
configuration is retained for the embedded buttons. Keyboard layout/offset, menu actions and
existing gesture calculations are retained. Regression checks cover black-margin
hit targets in all modes plus keyboard/dock/menu UI interactions.

Runtime check: a simulator HID swipe beginning at (110, 200), above the desktop
frame (y=337.875...574.125), reached NativeCanvasView.touchesBegan through UIKit's
UIWindow event dispatch. With a debugger-injected local image (no remote session),
black-margin swipes updated the local cursor position. Multitouch scale/pan is
covered by regression calculations; a physical two-finger gesture has not yet
been verified. The locked Mac prevented manual Simulator pinch testing.

Reconnect card button hierarchy
-------------------------------
NativeImmersiveSessionView.swift enlarges the failure card to a maximum of 320
points with 24-point interior spacing and external side clearance. Reconnect is
a full-width, 52-point Rust-blue/white primary button and the default keyboard
action. Cancel has its own 48-point secondary filled background. Error text and
icon scale with the card, using adaptive material/colors. Only failure-card
presentation changes; reconnect and confirmation actions are unchanged.

Native shortcut keyboard sizing and direct-touch boundary
--------------------------------------------------------
NativeRemoteCanvas.swift presents NativeRemoteKeyboard through UITextView.inputView
instead of a separate SwiftUI overlay. It obtains the standard English layout's
keyboard frame before installing a self-sized UIInputView of the measured height;
no device-height constants or persisted sizing cache are used. The same keyboard
layout guide aligns the desktop's bottom edge with both keyboard types. Normal
system-keyboard selection is restored after this sizing step. NativeImmersiveSessionView.swift
removes the obsolete shortcut overlay, retaining the camera helper used by the
terminal. NativeSettingsView.swift compacts the shortcut rows at smaller heights
without removing keys. The native input-view approach follows Apple's input view
API: https://developer.apple.com/documentation/uikit/uitextview/inputview .

For touch/touch-new, NativeRemoteCanvas.swift now requires single-finger direct
input to start inside the displayed desktop and remain there. Leaving releases
the remote button and cancels the gesture until fingers lift; margin taps/long
presses do not send clicks. Outside fingers still participate in two-finger canvas
transforms. Mouse/trackpad black-margin pointer input is unchanged. Gesture help
reflects this boundary. Tests compare system/shortcut heights, video-edge alignment,
restoration and displayed-image hit boundaries; UI checks cover full width and
edge-key visibility. Only native iOS input presentation/routing changes; Rust,
terminal input, authentication and file transfer are unchanged.

Fixed control-menu order
-------------------------
NativeImmersiveSessionView.swift applies menuOrder(.fixed) to the session Menu,
preventing UIKit's anchor-proximity ordering from placing the destructive action
first. The existing declaration now consistently reads control mode, display,
quality/codec, audio/access, then disconnect at the bottom. Only menu ordering
changes; actions and confirmation behavior are unchanged.

Compact paged keyboard and custom shortcuts
-------------------------------------------
NativeShortcutKeyboard.swift contains a five-page native keyboard: 常用, 字母,
符号, 功能, 导航. Tabs and horizontal swipes select pages. Keys use rectangular
cells that fill the available page height; common shortcuts use a scrollable
three-column grid. The first page presents stored named combinations. Modifier
selection is one-shot, and custom combinations send their explicit flags through
the existing key API; symbol keys use the existing text API. No remote macros or
automatic command execution is added.

NativeRemoteCanvas.swift caps the panel at 28% of the viewport, with a 180-point
minimum and the measured system keyboard as its upper bound, replacing the prior
full-English-keyboard-height requirement per the compact redesign request. Its
native keyboard guide still aligns the video bottom to the panel top.
NativeShellModel.swift owns the local NativeShortcutLibrary; NativeSettingsView.swift
links to its settings/editor. Names, selected keys and modifier sets persist in
UserDefaults. Editing, swipe deletion, reordering and restoring defaults are
available. Default combinations use Command for the user's Mac and can be edited
for other systems. Read/save failures are surfaced in settings.

Runner.xcodeproj adds only the new native keyboard source. These changes affect
iOS shortcut presentation, its local settings and panel sizing; Rust, terminal,
file transfer, authentication and direct/relative pointer handling are unchanged.
Regression checks cover durable edits/order/deletion and modifier arguments,
height/alignment, paging and portrait/landscape edge/bottom keys. UI tests create
and remove a simulator-only shortcut without sending remote key events.

Taller shortcut panel and larger legends
----------------------------------------
NativeRemoteCanvas.swift raises the panel target from 28%/180 points to 34%/210
points, retaining the measured system keyboard upper bound. NativeShortcutKeyboard.swift
sizes common-shortcut rows from the actual item count and uses more columns in
wide layouts, so the current default list fits without scrolling. Tab, shortcut
and key legends increase in size; other page layouts and key dispatch stay the
same. The existing UI check now verifies the final common shortcut is visible in
both portrait and landscape alongside the edge/bottom keys. Only native shortcut
sizing and typography change.

Balanced keyboard symbol legends
--------------------------------
NativeShortcutKeyboard.swift renders Backspace, Return, Shift, Command and arrow
keycaps with SF Symbols instead of small Unicode font glyphs. Symbols use 27-point
medium weight (22 in compact layouts), balanced against the existing 21/16-point
text. The shared tile applies this consistently across all pages. Existing labels,
modifier selection and key dispatch are unchanged. The existing keyboard UI run
captures navigation and letter pages for visual inspection; no input logic changes.

Symbol-only navigation/editing keycaps
--------------------------------------
NativeShortcutKeyboard.swift extends the shared SF Symbol map to Home/End,
Page Up/Down, Escape, Tab, Control, Option, Insert, Delete and Space. The navigation
page now uses symbols throughout; the same functional keys on other pages match.
Letter, digit, punctuation and numbered function-key labels remain literal.
Accessibility names and remote key values remain unchanged. Only keycap rendering
changes; the existing UI run verifies paging and navigation/letter screenshots.

Keyboard symbol fine-tuning: NativeShortcutKeyboard.swift reduces shared symbol
size from 27/22 to 25/20 points (regular/compact), retaining text sizes, weight,
key frames, accessibility and input actions. This is a presentation-only change.

Shortcut panel without a system-keyboard flash
----------------------------------------------
NativeRemoteCanvas.swift installs the custom input view before requesting focus,
or directly reloads it when already focused. The obsolete English-keyboard probe,
queued replacement flag, frame-notification observer and input-mode override are
removed. Panel height now comes directly from its current 34%/210-point viewport
rule, which no longer needs a system keyboard measurement. Explicit system-keyboard
selection still works. A real-window regression check opens the panel twice and
checks that its input view is installed immediately and that no normal keyboard
frame is presented while the shortcut panel is requested. Only native shortcut
presentation changes; remote key dispatch, pointer handling and terminal input do
not change.

Reference keyboard height and translucent dock
----------------------------------------------
NativeRemoteCanvas.swift sizes the shortcut panel to 45% of the viewport with a
240-point compact minimum, matching the supplied keyboard's approximate vertical
proportion. It still opens directly, and the keyboard guide aligns the video
bottom to its top. NativeImmersiveSessionView.swift replaces only the floating
three-button bar's background with 72%-opacity ultra-thin material; foreground
icons remain fully opaque. Menu/dialog materials, button actions and touch bounds
are unchanged. Existing keyboard checks cover the reference proportion, edge
alignment, direct presentation and portrait/landscape interaction.

Separate browsing from pinch-following canvas movement
------------------------------------------------------
NativeRemoteCanvas.swift uses a feature-local NativeTwoFingerGesture to distinguish
vertical browsing from canvas transformation in all four input modes. Parallel
two-finger motion sends vertical wheel deltas only. Separation must change by
more than both 12 points and 8% before a pinch begins; the same pair may then pan
while scaling stops, until either finger lifts. New pairs establish a fresh
baseline. The old immediate letterbox/legacy-mode pan paths are removed. Three
fingers now send horizontal wheel deltas only, replacing the old vertical wheel
or touch-new canvas pan. Single-finger mode behavior remains unchanged.
NativeSettingsView.swift updates the operation footer and gesture descriptions.
Regression checks replay vertical browsing with slight finger-distance jitter,
transition to pinch/pan, release and a new non-panning gesture. Existing canvas
transform and image-boundary checks remain. Rust, keyboard and terminal paths
are untouched.

Recognized pinches also consume the tap gesture, preventing a short pinch from
triggering the existing two-finger right-click action on release.

Touch sampling reads all active touches in each UIKit event, keeping each pair's
positions synchronized rather than comparing one updated finger with a stale
position for the other.

### Unified native confirmations
Connection errors, insecure-connection consent, informational prompts, operation errors, and disconnect confirmation now use the same system alert presenter on the active root or sheet. Credential and 2FA entry remain forms. The immersive waiting/failure status is hidden while another presentation is active; the former material reconnect card is removed, and cancelling a failed connection closes directly without stacking another confirmation. Device delete/forget confirmations also use alerts. Settings → Connection adds a persisted, default-off “跳过断开连接确认” toggle; all explicit disconnect actions share requestDisconnect(), including terminal/files via send(). Security consent is never bypassed by that setting. Regression surface: root/sheet alert routing, connection error suppression, retry/cancel, all four session exits, device delete/forget.

### SwiftRust application identity
The iOS Runner uses bundle identifier `swiftrust.airefactor.me` in all configurations, with matching test bundle prefixes. Device project generation and launch scripts use the same identifier. CFBundleDisplayName and CFBundleName are SwiftRust. This creates a separate installation from the former bundle identifier; existing app-container data is not migrated. RustDesk URL compatibility and protocol identifiers remain unchanged.

Device signing uses the developer’s own Apple team, supplied through SWIFTRUST_TEAM_ID or selected in Xcode. No personal team identifier is included in the shared project.

### SwiftRust orange app icon
SwiftRustIcon/SwiftRust.icon is the editable Icon Composer source and the Runner app icon in every configuration. Its white vector S with opposing arrowheads represents bidirectional control, over an orange automatic gradient. The mark is scaled 1.16 around the canvas center, with a compensated 68.965517-unit stroke so the final stroke remains 80 units, matching the original thickness while retaining the larger mark. SwiftRust-bold-1024.png is a historical thicker preview, not the current runtime icon. The .icon is compiled by the asset catalog compiler for system appearance variants; the exported 1024px PNG is a review asset, not the runtime icon. Only icon resources/build settings change; connection UI and protocol branding are untouched.

### Alternate app icon selection
Settings → Appearance → 应用图标 offers orange (primary/nil) and SwiftRust-Blue via UIApplication.setAlternateIconName. Selection is read from the OS on entry and when becoming active; a successful completion commits the requested selection immediately, no duplicate persisted preference. Switching is disabled while pending or unsupported; errors use the shared native error alert. Both .icon sources compile through primary/alternate asset catalog build settings, including iPad entries. Small preview images are separate UI assets. Regression surface: alternate icon metadata, preview/selection, system change notification and persistence across relaunch, restore primary orange.

The icon list also offers SwiftRust-WhiteOrange and SwiftRust-WhiteBlue: white default backgrounds with orange/blue SVG gradient S marks, retaining the same scaled geometry and compensated stroke. Both have independent Icon Composer sources, preview assets and alternate-icon build entries. The existing orange primary remains the default. The icon switching regression now exercises both added names before restoring primary.

### Control menu and shortcut keyboard refinements
Control Mode now owns remote cursor visibility and standard/reversed scroll direction (existing reverse-mouse-wheel session option applies to touch browsing and physical scrolling). Desktop first-frame setup enables show-remote-cursor by default; successful explicit changes persist in native.show-remote-cursor, with administrator-fixed options respected. Other input permissions remain unchanged. Floating toolbar tint is explicitly white.
Shortcut keyboard uses rounded upper corners and adaptive system-keyboard-like surface/key fills, including its header buttons. Function and navigation keys share one four-row page, retaining F1–F12, navigation/edit keys and modifiers. Settings → Custom Shortcuts adds a default-on persisted key haptics toggle; feedback applies only to key/modifier/custom-shortcut taps. Regression surface: new-session cursor preference/application, control menu placement, existing wheel reversal, four-page layout in portrait/landscape, keyboard switching and haptics preference persistence. No Rust/core changes.

Control display lock now includes a lock/unlock symbol. Global Settings → Operation adds a default-off canvas lock preference applied at session creation. Sound & Access adds persisted, default-off connection statistics. The read-only 184pt rounded material card sits at the safe upper-left inset and does not intercept gestures. Existing update_quality_status events supply speed, current-display FPS, delay, target kbps and codec; missing data shows a dash, partial updates preserve prior values, and new/reconnected/closed sessions clear old metrics. No core or Flutter UI is introduced.

The statistics overlay also uses the current window safe-area insets because the full-screen canvas ignores SwiftUI safe areas; it remains clear of camera occlusions in portrait and landscape. Device Hub's Toggle Software Keyboard must be enabled for the system-keyboard UI test; hidden simulator software keyboards can expose an accessibility keyboard without a visible keyboard layout guide.
Local Ad Hoc signing now uses the explicitly authorized Apple Distribution certificate and the manual SwiftRust AdHoc Local Air Duo profile. The signing private key is stored in the login keychain and the temporary PEM key was removed after import. ExportOptionsLocal.plist selects the matching certificate/profile without an Xcode account network session.

### Keyboard spacing, menu stability and disconnected video
Shortcut keys use 8pt gutters, 18pt top padding and slightly smaller labels. UIInputView uses the default style with an opaque shared adaptive background, matching the SwiftUI surface through the bottom safe-area strip. System keyboard rendering remains unchanged.
Quality updates publish through NativeConnectionMetrics, observed only by the statistics card. They no longer invalidate the shell/menu/keyboard through NativeShellModel.objectWillChange; unchanged values do not publish.
Connection errors clear the video and dismiss input; late frames are consumed but ignored while failure is active, so they cannot reconnect the UI. Retry clears failure and awaits new frames. The disconnected status uses filled reconnect/cancel buttons; cancelling a failed session closes directly. Native security/credential/disconnect alerts retain their existing route. Regression surface: custom keyboard bounds and common/function-page visibility, metrics delivery without menu invalidation, failure/late-frame/retry rendering.

### Foreground desktop reconnection
NativeSettingsView adds an opt-in connection toggle (off by default). SceneDelegate.sceneWillEnterForeground calls NativeShellModel.reconnectOnForeground: reconnect an existing desktop session or open the last successfully displayed desktop ID. Connection errors can retry on foreground; password/security prompts and pending attempts are not interrupted; terminal/file sessions are not replaced. Only a successful desktop frame with a real session records the last ID; credentials continue through the existing core. Runtime changes are confined to these three native files and the build number.

### Scroll gesture locking and speed
NativeSettingsView labels the skip-disconnect toggle with an SF Symbol. NativeRemoteCanvas locks each two-finger gesture to scroll or pinch/drag until release, with a 6pt vertical intent threshold; starting a scroll also suppresses the two-finger right-click. Finger scrolling uses 1.5 pixel units per point through the existing trackpad protocol for Mac peers, and wheel steps per 12pt for other peers (previously 20pt). Fractional deltas accumulate; physical wheel sensitivity remains unchanged. Three-finger horizontal browsing uses the same touch speed. Regression surface is limited to this settings label and native two/three-finger scrolling; Rust/server paths are unchanged.

### Adjustable touch scrolling speed
Independent speed controls: NativeScrollSettings exposes a persisted 0.25–3× slider (default 1×), reset and immediate application. NativeSettingsView links from Operations and the Control Mode menu; NativeShellModel.NativeSheet.scroll and NativeShellView route the session sheet. NativeRemoteCanvas.scroll multiplies touch scrolling deltas for both two-finger vertical and three-finger horizontal browsing; physical wheel sensitivity and relative pointer movement retain their existing behavior. Pointer movement speed remains independently adjustable in NativePointerSettings via native.pointer-speed (same 0.25–3× range and 1× default), applied only in NativeRemoteCanvas.relative. Regression surface: these native settings/sheet routes, touch scroll gain, and relative pointer movement.

### Remote resolution and adaptive phone window
NativeResolutionSettings restores remote supported modes, original resolution and custom dimensions for displays advertising original size 0×0 (RustDesk virtual/custom-resolution convention). NativeRustCore.NativeResolution decodes both native array and wrapped resolution lists and selects the nearest supported aspect ratio, breaking ties by pixel area. NativeShellModel tracks peer/switch_display resolution events and routes dimension requests through the existing core session_change_resolution API; ios_native.rs adds only its guarded JSON route, honoring keyboard permission and view-only mode.
A persisted fit-phone-window mode refits NativeRemoteCanvas whenever its actual bounds change (including Duo folding/unfolding and rotation), requests the nearest supported mode or exact window pixel size for custom displays, and fits video above the keyboard without changing remote resolution for keyboard transitions. One last requested display/resolution key prevents response events from retriggering identical remote requests; new connection/reconnect/manual selection resets it. Manual resolution/original-size choice exits adaptive mode.
Regression surface: NativeSettingsView and NativeShellView menu/sheet entry; NativeRustCore resolution values; NativeShellModel display metadata/selection; NativeRemoteCanvas geometry/keyboard fit while adaptive mode is enabled; the iOS-only Rust resolution request branch. Existing Rust protocol/server behavior and manual canvas gestures remain in place.

### Compact glass input adjustment
Control Mode now opens one NativeInputAdjustmentPopup for pointer size, pointer movement speed and touch scrolling speed. It overlays the desktop in a single regular Liquid Glass surface (ultraThinMaterial fallback before iOS 26), with native sliders, immediate effects, shared persisted speed preferences, reset and outside/close dismissal. Main settings pages remain available. NativeImmersiveSessionView hosts the overlay; NativeShellModel dismisses it before connection errors, reconnect or disconnect so confirmation windows do not stack. No scale animation is added.

### Compact resolution selector
The control-page resolution action opens NativeResolutionAdjustmentPopup over the desktop instead of its Form sheet: one regular Liquid Glass surface (material fallback), current size, adaptive-window switch, two-column scrollable advertised-mode buttons with actual-size selection, original-resolution action, and inline custom dimensions for supported virtual displays. Popup height budgets follow the current window; close/outside tap dismisses it. NativeShellModel clears both adjustment overlays before error/reconnect/disconnect; NativeImmersiveSessionView renders at most one. Regression surface is limited to control-page presentation/menu opening and overlay dismissal in these native views/model. Resolution selection, permissions, persistence, Rust bridge, keyboard/canvas geometry and main settings routes retain their prior behavior.

Resolution selector redesign files: NativeSettingsView.swift (popup grid and menu opening), NativeImmersiveSessionView.swift (overlay presentation), NativeShellModel.swift (overlay dismissal before errors and session termination).

### Landscape keyboard and refined pointer sliders
NativeRemoteCanvas uses 39% of landscape window height (200pt minimum) for the shortcut input view; wide portrait windows (width/height ≥ 0.62, including expanded Duo) use 37.5%/240pt minimum, while narrow phone portrait retains 45%/240pt minimum. Bounds changes recreate the same custom keyboard type at the new window width/height, preserving shortcut keyboard mode through rotation without a system-keyboard probe; its page returns to Common. NativeShortcutKeyboard tightens only compact header/row/padding spacing to retain four rows at the shorter height.
NativeSettingsView replaces the control popup's three sliders with native UISliders using a fine track and 22pt circular thumb; range, snapping and persisted values are unchanged, and pointer size still saves when editing ends. Labels/values are larger and white; restore-default text is white with a subtle button background. Regression surface: these three native files' custom input height/layout and popup slider editing paths; main settings sliders/system keyboard rendering remain unchanged.

### Restore outer-screen keyboard sizing
NativeRemoteCanvas now requires a window short side of at least 550pt before applying expanded-window keyboard proportions. Narrow/outer windows retain the original max(240pt, height×45%) in both orientations; wide expanded portrait/landscape retain the screenshot-based proportions. Compact typography again applies only below 220pt, preserving outer-screen padding and key fonts at its original 240pt height. Regression surface: shortcutKeyboardHeight classification and the input view compact threshold in NativeRemoteCanvas.swift, with expanded/outer-window and orientation regression checks; rotation recreation and all remote input behavior are unchanged.

### Keyboard-open cursor flicker and interrupted dragging
NativeRemoteCanvas now tracks actual UIWindow bounds separately from internal canvas bounds. Only a real window resize recreates the custom input and releases pointer buttons; keyboard/content relayout merely realigns layers. Keyboard dimensions and adaptive resolution requests use that same actual window size, avoiding transient content-size feedback. Keyboard lift differences ≤0.5pt are ignored. Explicit keyboard-position animation applies only to video, so cursor movement remains immediate instead of being overridden by a stale animation target.
Regression checks first reproduced keyboard identity replacement during stable-window relayout, cursor position animation, and 0.1pt canvas jitter, then verify their absence along with normal keyboard alignment and real orientation resizing. Changed runtime paths are confined to NativeRemoteCanvas.swift layoutSubviews, adaptResolutionToWindow, shortcutKeyboardHeight/showShortcutKeyboard and setKeyboardLift; remote mouse speed/protocol and keyboard size policies are unchanged.

### Control-menu cursor ownership and zoom floor
A real-touch debugger probe reproduced a stale remote cursor coordinate replacing the local cursor during an active trackpad gesture (60,60 → 1,1). NativeRemoteCanvas now ignores remote position backfeed only while an editable relative touch gesture is active; idle, read-only and direct-touch sessions continue accepting peer positions. NativeShellModel polls events in common run-loop modes so native menu/tracking interactions do not pause delivery. NativeFloatingDock releases existing touch/button state when the settings menu is tapped.
Display settings adds a persisted, opt-in minimum-zoom-at-window-width toggle. NativeRemoteCanvas derives its magnification floor from image and viewport aspect ratio, applies it during zoom/fit/size/keyboard changes, and preserves previous zoom behavior when disabled. Scope: NativeRemoteCanvas cursor/zoom paths; NativeShellModel event timer and zoom preference; NativeSettingsView display toggle; NativeImmersiveSessionView menu tap. Backend protocol, pointer speed and remote resolution remain unchanged.

### Canvas gesture haptics (87)
NativeRemoteCanvas emits a light UIKit impact on entering relative or direct dragging, on the first nonzero touch scroll per contact sequence, and when zooming crosses the minimum scale. Continued dragging, scrolling and zoom attempts while already at the floor do not repeat feedback. Physical wheel scrolling and automatic fit/layout do not trigger haptics. Runtime changes are confined to the native canvas; keyboard haptic preferences remain independent. Validate vibration strength on a physical iPhone.

### Background disconnect settings (88)
Settings → Connection → Disconnect Settings groups the existing skip-confirmation preference and a persisted background timeout (0/10/30/60 seconds or -1 system maximum, default -1). SceneDelegate begins one finite UIKit background task before deactivation, releases held input, and closes the native session at the selected timeout or UIKit expiration, whichever comes first. Returning foreground cancels the timeout and balances the task; temporary inactive interruptions do not start a disconnect countdown. No background audio/VoIP entitlement or repeated task renewal is used. iOS may suspend/terminate earlier and does not guarantee any fixed duration. Foreground auto-reconnect now leaves an already connected preserved session intact. Changed runtime paths: SceneDelegate lifecycle, NativeShellModel foreground reconnect guard, NativeSettingsView connection preferences. Physical background duration must be validated without a debugger attached.

### SwiftRust source and license preparation (89)
NativeSettingsView → About now identifies SwiftRust and opens an offline legal/source page with derivative attribution, modification date, warranty/license notice, full AGPL, SwiftTerm and collected third-party texts. The optional Info.plist SwiftRustSourceURL accepts only a configured HTTPS URL; absent a real cloud URL, the UI explicitly says source address pending and does not claim source is available. AGPL-3.0.txt and ThirdPartyNotices.txt are bundled resources. No connection/input paths change in this step. Source preparation, build patches, archive instructions and remaining publishing obligations live in docs/swiftrust; scripts use repository-relative paths and caller-supplied signing configuration. Desktop project is SwiftRust, upstream remains the RustDesk remote, no cloud push or OTA publication performed for this preparation build.

### License evidence review
The 46 missing-root-license findings were individually reviewed: 27 license texts recovered at upstream locked commits, 3 LICENSES-directory false positives corrected, 6 modules covered at the RustDesk main-project scope, 2 license roots recovered after all Rust sources matched an upstream snapshot byte-for-byte, and 2 MPL-2.0 webm entries supplemented with Mozilla's text and the nested libwebm BSD notice. Six remain explicitly pending; no authorization or copyright notice was invented. collect-notices.py verifies version/source/checksum and saved evidence SHA-256, incorporates reviewed notices and emits the pending list. Runtime impact is limited to the offline notices resource; no connection, gestures or signing changes.

### Native proxy input and endpoint latency (90)
NativeProxySettings.swift replaces the old single ambiguous address field with an explicit SOCKS5/HTTP/HTTPS choice and domain-or-IP:port input. Full URLs (including a root slash), SOCKS alias, IPv4 and bracketed IPv6 normalize to a canonical URL before using the existing saveProxy route. Bare host:port follows the chosen protocol instead of always implicitly becoming SOCKS5. Reject invalid ports, paths/query/fragment and embedded credentials with inline errors. The existing core still validates DNS; save runs that synchronous C ABI call on a background Task to keep the UI responsive. No Rust proxy protocol or TLS policy changes.

NativeProxyProbe uses Apple's Network framework for a bounded 8-second DNS/TCP connection measurement to the entered proxy endpoint. The page explicitly states this does not test proxy authentication, protocol support, HTTPS certificates or end-to-end desktop latency. Cancels on editing/protocol change/navigation and ignores stale connection callbacks by identity. Authentication data is not sent during latency testing or logged. Actual failing user proxy was not supplied, so no claim is made that all HTTPS/SOCKS transport failures have been fixed.

Regression surface: NativeSettingsView's advanced-settings navigation label and moved proxy view; new NativeProxySettings form/input normalization/probe/save scheduling; project source registration and build number. Shared Rust, hbb_common, Flutter and other platforms retain their existing runtime paths. Tests cover endpoint parsing, a real loopback TCP handshake/result clearing, and UI URL input/failure presentation without saving or changing the user's proxy.

### Embedded userspace Tailscale (91)
NativeTailscale.swift owns a process-local libtailscale/tsnet node, interactive Tailscale web authorization in SFSafariViewController, state/peer display, enable/disable/logout and direct RustDesk device connection. No NetworkExtension, VPN profile or system route is created. Node state stays in an app-private, file-protected Application Support directory excluded from backups. Logout removes this local node state; it does not promise removal of an existing machine record from the Tailscale administrator console. No auth key is embedded. Tailscale auth URLs, node keys and generated proxy credentials are not logged; the adapter uses the official no-log-upload option.

A loopback-only SOCKS5 listener with cryptographically random per-listener authentication bridges the Rust client to tsnet.Dial. Client::_start has a seven-line iOS-only hook, activated only for configured Tailnet IP ranges, .ts.net DNS names or discovered peer names. Route credentials remain in process memory, not Config::set_socks; normal RustDesk ID/server traffic and the user's HTTP/SOCKS configuration keep their old path. A Tailnet route failure does not retry through a public proxy. SceneDelegate rebinds only the userspace listener on foreground to recover from iOS reclaiming suspended listeners, without restarting the node or closing existing streams, before the existing reconnect decision. The normal background expiration/disconnect policy remains in force.

Build: official libtailscale dacde75057ff350e146505829beff446e6823966 / tailscale.com 1.104.1, SwiftRust Go adapter in scripts/ios/tailscale/swiftrust.go; static archives built for device/simulator by build-tailscale.sh. Dependency notices for the 29 used Go modules and Go runtime are bundled in TailscaleNotices.txt. No new Rust crate/submodule or Flutter runtime was added. BUILD_IOS.md and TAILSCALE.md describe prerequisites and remaining live verification.

Regression surface: NativeTailscale (new feature), NativeSettingsView entry/notices, NativeShellModel feature ownership and pre-connect readiness check, SceneDelegate foreground listener rebind, iOS-only ios_native route storage and Client::_start thin branch, Native.xcconfig/bridging header/source registration. Default disabled follows existing non-Tailnet runtime paths. SDK smoke tests exercise actual node startup/status and authenticated SOCKS negotiation using temporary ephemeral state; no real account or peer connectivity is claimed before user authorization.

### Original RustDesk gestures restored (91)
Mouse/touch use original multi-finger mapping from base remote_input.dart / gesture_help.dart: two fingers pan/zoom the canvas directly, three fingers vertically scroll. Mouse retains relative single-finger movement, double-tap-and-hold drag, long-press right click; direct touch retains absolute tap/one-finger drag and long-press right click. Trackpad/touch-new keep the newer two-finger scroll lock, three-finger horizontal browse and pinch-then-pan path. Existing pointer/scroll speed controls, fixed cursor size, image-only direct taps and margin zoom remain. NativeTwoFingerGesture has an opt-in canvasOnly branch; its default new-mode path is unchanged. Help is mode-specific. Tests assert legacy pan versus modern scroll for the same two-finger motion and preserve modern scroll locking.

### Native language settings and Apple Translation (92)
NativeLocalization.swift restores Settings → Language with Follow System and the original 53 RustDesk languages. collect-native-languages.py builds NativeLanguages.json from the checked-in RustDesk language tables and fixed native UI templates. NativeL/NativeF resolve presentation text; protocol keys, stored input modes, device names, custom shortcut content and entered text keep their existing values. Locale changes redraw observed native views without replacing the session model or restarting connections. System preference resolution includes Chinese script and Portuguese region handling, and the root applies the selected locale/layout direction.

On iOS 18+, LanguageAvailability contributes additional Apple-supported languages. Users may prefer existing RustDesk translations (Apple fills missing UI templates) or choose Apple Translation as the primary source. The explicit generation button uses a SwiftUI translationTask/TranslationSession, checks availability, allows Apple's language-download consent UI, translates fixed interface templates in batches, validates placeholder counts and atomically caches results in Application Support. It never submits peer names, credentials, keyboard input, clipboard, terminal text or remote desktop images. Unsupported Apple language pairs retain the original/bundled text and show an explanation. Failed or cancelled batches retain completed valid cache entries for retry. Switching the target/provider cancels that page's active translation task.

Regression surface: native view literal/dynamic-label presentation in NativeSettingsView, NativeShellView (including confirmations), NativeImmersiveSessionView, NativeDeviceSessions, NativeShortcutKeyboard, NativeProxySettings and NativeTailscale; the new localization store/settings UI, bundled JSON, project registration/version. No Rust transport, gesture dispatch, persisted protocol settings or submodule changes. Regression checks cover existing translation lookup/system fallback, placeholder validation, and visible language switching/persistence. Apple model download and actual generated output require an Apple-supported device/language pair and remain a separate live check.

### Proxy switch, Auth key and automatic translation (93)
NativeProxySettings adds an explicit enable switch, applied with the existing Save action. Active settings still use the unmodified saveProxy/loadProxy ABI. Disabling clears the core proxy, while a Codable draft (including credentials) remains in the app's private Keychain, AfterFirstUnlockThisDeviceOnly. Loading prefers an active core proxy and otherwise restores the draft even when loadProxy returns an empty array. Endpoint latency testing remains available independently of activation. No new proxy protocol, Rust configuration or hbb_common path is introduced.

NativeTailscale adds SecureField Auth key enrollment, using the official tailscale_set_authkey before tailscale_start. Submitting clears the field; the Auth key is not written to UserDefaults, Keychain, logging or an app configuration file. The SDK retains its normal node identity state. Re-enrollment restarts only an unauthenticated local node; changing an already-running account requires logout first, and the UI disallows key enrollment during an active remote session. Web login remains available. A real valid Auth key and Tailnet approval/connection remain live verification requirements.

Language UI now has one path: bundled translations first, automatically fill missing fixed UI templates using Apple Translation and cache them. The source-mode picker and manual generation step have been removed. The root owns the translation task, language changes cancel it, Apple unsupported pairs show an explanation, and failed/download-cancelled runs can be retried from Language. Apple's own model-download consent may appear. On pre-iOS-18 systems only bundled/cached translations are available. No user content is submitted for translation.

NativeL normalizes the visible product name to SwiftRust in every language, including cached translations; only offline attribution/upstream/legal views opt out, preserving RustDesk names and license text. Login, QR hints, classic-gesture descriptions, server hints, default remote title and icon option text were updated. Protocol URI schemes, API behavior and upstream license/copyright sources are unchanged.

Regression surface: NativeProxySettings form/draft persistence, NativeTailscale runtime startup and enrollment UI, NativeLocalization lookup/automatic translation, NativeShellView root translation and visible labels, NativeSettingsView visible labels/legal opt-out, NativeShellModel fallback display name, language collector/resource and build number. Tests cover real Keychain draft retention with core proxy off, Auth key validation, product/attribution display, native controls, and language persistence. No Rust core, submodule, gesture dispatch or desktop connection transport changes.

### Exact window resolution adaptation (94)
Automatic adaptation now always requests the current UIWindow bounds multiplied by that window screen's backing scale. NativeResolution.windowPixels validates the existing 64–8192 protocol range and rounds only fractional pixel coordinates; odd dimensions are retained. NativeShellModel no longer selects a closest supported mode or gates exact requests on customResolution metadata. Existing per-display/request deduplication, read-only/permission checks, manual resolution selection and keyboard canvas layout remain. Rotation/fold/unfold uses the existing UIWindow size-change path. A remote display that cannot apply the exact requested size keeps its existing mode; the client does not substitute a nearby mode. Creating arbitrary modes on unsupported remote physical monitors is not provided by this iOS change.
Regression surface: NativeResolution pixel-size helper, NativeShellModel automatic-resolution selection, NativeSettingsView explanation and language resources/build number. No network ABI, Rust core, desktop display driver or gesture changes. Tests cover exact odd dimensions in portrait/landscape/expanded-window sizes, display metadata updates and the existing read-only resolution denial.

### SwiftRust 1.0.0 and lightweight legal documents (95)
Runner MARKETING_VERSION is now 1.0.0; CURRENT_PROJECT_VERSION continues monotonically at 95. The upstream Rust/Cargo version is unchanged. Open-source settings no longer list individual third-party component entries: the separate Tailscale/SwiftTerm/third-party links are consolidated into one License and Copyright Notices entry. Complete existing Rust/native-codec/SwiftTerm and Tailscale notices remain bundled and readable/exportable; AGPL and upstream attribution/source access remain available.

The previous NativeLicenseText read approximately 4.5 MB synchronously from a computed property and passed the entire document into a single SwiftUI Text layout. It now loads resource files once per document task off the main actor, shows loading/error state, then splits the exact original text into bounded 16,000-character pages off-thread and uses a read-only, scrollable TextKit 2 UITextView for one page. A single native text view was also too costly for the full 4.5 MB file, so the final implementation never assigns the whole file to a text layout engine. Page controls recreate only the bounded current-page view; localization redraws do not reload files or reassign its text. Original notice contents are displayed verbatim; bundled files are not edited or translated. ShareLink exports the original source notice files.
Regression surface: NativeSettingsView legal navigation/document rendering, bundled UI language templates and Runner version metadata. Connection/input/translation engines, license files and dependencies remain unchanged. The UI regression opens AGPL, opens/scrolls/pages through the combined large notice document and returns, checks export availability, and verifies individual component entries are absent. A unit regression joins all pages to prove the complete document and Unicode are preserved. No before/after Instruments capture or numeric frame-time improvement is claimed.

### Visible canvas adaptation, resolution selection and plain login (96)
NativeCanvasView now tracks its own bounds minus keyboard occlusion and the view's display-scale trait, rather than using the whole UIWindow. Existing fold/rotation layout, canvas-only resize (including split windows), keyboard height changes and UITraitDisplayScale changes all recompute the exact available-pixel target. The target is shown beside the current desktop mode. Automatic requests wait 250 ms for layout to settle and retain exact-size behavior; Mac physical displays can reject arbitrary sizes, and the UI explains that exact arbitrary adaptation requires a custom-resolution virtual display. No virtual display is created on the Mac by this iOS change.

NativeShellModel schedules resolution changes through a dedicated serial background queue, keeping core locks/request work off the UI thread. The C ABI accepts an optional expected session UUID and refuses a request if the current session has changed; the queued call remains bound to that UUID. Cancellation, session resets and permission checks retain their current behavior. Metadata/permission readiness paths retry adaptation, and a failed request clears its auto-target deduplication key so a later ready event can retry. This is the only changed Rust path, inside the native iOS module.

NativeDisplay reads peer_info scaled_width to distinguish Mac HiDPI video dimensions from desktop mode dimensions, and preserves the display scale across switch_display messages until sync metadata updates it. Both selectors show the actual current desktop with a checkmark, including while auto fit is on; the current mode is included even if absent from the advertised choices. The popup can scroll when the complete controls do not fit a short landscape window. Login's settings label is now simply Sign in, with no product-name prefix.

Regression surface: NativeRemoteCanvas layout/keyboard/trait sizing, NativeRustCore resolution queue/pixel helpers and NativeDisplay mode calculation, NativeShellModel resolution scheduling/readiness and display metadata, NativeSettingsView resolution controls/plain login label, iOS-only resolution dispatch session check, language templates/version registration. No shared transport, server driver, protocol message or hbb_common changes. Tests cover outer/inner-style portrait/landscape/split/keyboard pixel targets, HiDPI current-mode selection with auto fit, replacement-session rejection and read-only denial; UI checks cover popup rotation/closing and the plain login entry. Physical Duo scene transitions and exact mode acceptance by the user's Mac still require live validation.

### Offline privacy statement and settings Dock visibility (97)
NativePrivacyView adds Settings → About → Privacy Statement, with fixed offline text covering remote sessions and configured servers/proxies, account credentials and device metadata, local settings/files, private Keychain proxy drafts, optional Tailscale enrollment/node state/service metadata, automatic Apple UI translation, QR-camera/file permissions, diagnostic information and available deletion/support paths. Links point to the official Tailscale and Apple privacy policies. It does not claim that all networking is local, that service operators keep no metadata, or that uninstalling clears Keychain/server records. No new analytics, permissions, storage or data collection is introduced.

The settings NavigationStack hides the system TabView Dock for its root and pushed pages, including privacy, open-source and paged license documents. The settings root adds a normal Return Home navigation action; returning to Home restores the Dock. Privacy also explicitly opts out of tab-bar display. Home/Favorites and the remote-session floating toolbar retain their previous behavior.
Regression surface: NativeShellView settings-stack tab-bar preference/root navigation item, NativeSettingsView About entry, new NativePrivacyView, bundled language templates and project source/build registration. UI regressions cover settings/privacy/legal/license Dock hiding, document access, Return Home restoration and existing home/account navigation. Privacy content describes the current implementation; a future public distribution still needs actual publisher/support information and service-specific disclosures as applicable.

### Statistics source/unit audit (98)
The HUD now distinguishes the actual logical desktop mode (NativeDisplay scaled_width/HiDPI calculation, matching resolution selection) from the decoded RGB image dimensions measured in NativeCanvasView.displayFrame. It no longer presents unlabeled capture metadata as though it were the selected desktop mode. Video dimensions clear when the current image/display is cleared and all metrics clear on connect/reset/reconnect/failure/disconnect.

Source audit: client/io_loop.rs increments frame_count when decoded images reach the UI callback and reports interval counts approximately once per second, so the HUD explicitly labels decoded FPS (not display refresh rate or actual presented frames). The same loop reports received peer-message payload bytes divided by elapsed time and 1024; the HUD corrects the core's kB/s label to KiB/s without another numeric conversion. This is received session data, not total NIC traffic, and excludes some transport overhead. ui_session_interface::handle_test_delay supplies the server's last network round-trip sample in milliseconds and its reported encoder target bitrate. The HUD labels RTT and target kbps rather than implying one-way interaction latency or measured download bitrate; multi-display target bitrate is server-reported, not guaranteed to be exclusively attributable to the currently selected display. Codec and chroma are the core's current reports, with unknown values retained as unknown.

The native iOS event queue previously discarded earlier update_quality_status events, despite those events being partial (e.g. RTT/target bitrate versus FPS/speed/codec). It now retains these low-rate partial notifications; only high-rate cursor positions are coalesced. Swift merges partial values, treats an empty FPS map as no new FPS sample, clears FPS on display changes or a fresh nonempty map missing that display, preserves valid zero samples, and ignores malformed negative/nonnumeric delay/bitrate values. Measurements remain isolated in NativeConnectionMetrics so regular refreshes do not invalidate control menus; image dimensions publish only when changed. No new logging, analytics or network measurements were added.
Regression surface: native iOS event retention, NativeShellModel metrics merge/reset/display change behavior, NativeRemoteCanvas decoded-dimension recording, NativeConnectionStatistics labels/layout and language/build metadata. No encoder, QoS, timer, server driver or transport algorithm changes. Tests cover independent HiDPI/decoded dimensions, rate-unit labeling, partial updates and resets, per-display FPS/zero/invalid samples, and isolation from control-menu invalidation. Actual peer network measurements were traced to core source; no external calibrated latency/bandwidth benchmark or physical-network accuracy claim is made.

### Remove phone-window desktop adaptation (99)
Removed the phone-window adaptation controls, target-size display/explanations, fitPhoneWindow preference reads, viewport/scale/keyboard listeners that requested desktop modes, readiness retries and automatic request debounce/deduplication. An old native.fit-phone-window preference is no longer read and cannot reactivate the feature. Resolution screens/menu now say Resolution. No remote virtual-display creation is attempted.

Manual mode/custom-size selection, asynchronous session-bound core dispatch, permission checks, HiDPI actual-mode checkmarks and the statistics fixes remain. Fit to Screen, Original Size, normal pinch/canvas operations and keyboard-bottom alignment remain local rendering operations; resizing the app/folding/rotating no longer causes this native frontend to request a desktop mode. Removed auto-only pixel/resize tests; regression checks retain manual fit/keyboard alignment, actual HiDPI mode selection, read-only rejection and popup rotation/dismissal while a retired preference is forced on.
Regression surface: NativeShellModel resolution entry points and removed preference/task scheduling branches; NativeRemoteCanvas scale/keyboard/window callbacks reverting to their regular non-auto behavior; removal of the unused viewport pixel helper; NativeSettingsView controls/copy, language templates and build number. The Rust core, server display drivers, manually queued session guard and statistics paths are unchanged.

### English statistics labels and compact resolution dialog (100)
The compact HUD uses fixed English labels in all app languages: FPS, Delay, Speed, Codec, Chroma, Target bitrate, Desktop and Video. Codec/Chroma now have individual labeled rows. Text is verbatim so interface translation cannot change these technical labels; accessibility still identifies decoded FPS and round-trip delay. Only NativeConnectionStatistics presentation, removed unused language templates and build metadata changed. Metric sources, units, refresh/merge logic and transport remain as in build 98. Simulator compile validates this reversible presentation-only edit; no additional behavior tests were added.

The resolution dialog no longer wraps content in a ViewThatFits/full-height max frame. That frame stretched the glass surface to almost the screen height despite the short header/list/footer, creating the reported top/bottom void. Its glass now follows the controls' natural fixed vertical size, while only the bounded mode grid scrolls. Row size, mode selection and asynchronous resolution requests are unchanged. The existing popup regression asserts compact portrait height and an accessible, bounded landscape surface.

### Terminal shortcut keyboard (101)
The terminal now opens the existing four-page shortcut keyboard from a pinned Command button in the bottom/accessory bar or its settings menu. Common terminal shortcuts include Ctrl-C/D/Z/L/R/A/E/U/K, Esc, Tab and local paste, with user-defined shortcuts shared from settings. Keyboard replacement sets the custom inputView before becoming first responder, removes the extra accessory strip and restores it when switching to the system keyboard. Switching terminal tabs dismisses the old panel; reopening targets the selected tab. The two keyboard controls remain pinned beside the horizontally scrolling quick keys.

Terminal keys go through the active terminal's existing PTY input route, using classic xterm character/control and navigation/function-key sequences, including application cursor mode and modifier parameters. Local Command-C/V/A use selection, bracketed paste and select-all; unsupported GUI Command shortcuts are disabled. Desktop keyboard actions retain the existing remote key route. No terminal command is executed by the UI tests and newer extended keyboard protocols are outside this change.
Regression surface: NativeTerminalCanvas input/accessory replacement and rotation sizing, NativeTerminalContent menu, shared NativeRemoteKeyboard optional terminal dispatch, NativeShortcutInputView binding and new NativeTerminalKeys encoder. Encoder unit coverage and the existing desktop no-system-keyboard-flash test passed. Terminal UI coverage passed for all pages, system/custom keyboard switching, tab creation and dismissal. Live remote shell command delivery still needs peer testing.

### Full-width terminal keyboard accessory (102)
Wrap the terminal accessory hosting view in a system-sized UIInputView instead of installing a 320-point hosting content view directly. The content follows its container in both dimensions and the SwiftUI bar fills available width, keeping the pinned shortcut/system keyboard controls at the trailing inset on wider windows and after rotation. Existing horizontal quick-key scrolling remains unchanged. Regression: terminal keyboard-page/system-keyboard/tab-switch UI test now checks that the accessory hide button ends within 16 points of the window trailing edge.

### Restore session type and separate launch/background preferences (103)
Successful connections persist an atomic local id/mode record for desktop, terminal, file transfer and camera. Foreground recovery retains the active mode on an abnormal live session, or restores the saved mode after the background timeout closed it. Old desktop-only records remain a fallback until a new successful connection. Healthy, connecting, authentication-pending and confirmation-pending sessions remain untouched.
A separate default-off launch-restore preference controls fresh scene startup; the existing background preference only runs after sceneDidEnterBackground. Initial scene foreground delivery cannot accidentally invoke background recovery. Incoming URL startup does not auto-restore over its selected ID. Both paths share the saved-session restoration and normal connection authorization. Regression surface: firstFrame persistence, NativeShellModel lifecycle methods, SceneDelegate launch/background gating, settings/localized templates. Tests pass for mode restoration, enabled/disabled background behavior, healthy sessions, pending authentication and independent launch/background switches. Terminal accessory trailing-edge UI regression also passes.

### Keyboard hosting content width constraints (104)
The terminal accessory now pins all four hosting-content edges with Auto Layout rather than relying on a hosting configuration's autoresizing/intrinsic size. Terminal layout updates the accessory width from its current window, including Duo outer-screen resizing. The shared custom shortcut input view also pins its content to all four edges. No fixed display resolution is assumed. Regression surface: terminal system-keyboard accessory content sizing and shared custom keyboard hosting layout; no key dispatch or session behavior changes. Tests exercise hosted content widths 390/690/920/600 points and terminal page/system-keyboard/tab switching with trailing-edge alignment. Physical Duo outer-screen appearance requires user confirmation.

### Terminal toolbar owned by the app layout (105)
Build 104 still left unused space in the system keyboard accessory on physical Duo outer screen, despite the simulator trailing-edge check. Remove the terminal inputAccessoryView completely. Render one terminal shortcut bar in NativeTerminalContent's full-width VStack both while idle and above the system keyboard; SwiftUI's keyboard safe area positions it. The bar uses the hide-keyboard action while the terminal is first responder. Hide it only for the custom shortcut keyboard, whose own header supplies keyboard controls. This avoids sizing SwiftUI content through a third-party keyboard's accessory host. Regression surface: terminal keyboard safe-area layout and toolbar ownership only; custom keyboard sizing/PTY dispatch unchanged. Unit regression asserts no terminal system accessory; UI regression exercises system/custom keyboard and tabs, including the trailing inset. Physical third-party keyboard layout remains to be confirmed on Duo.

### Explicit home refresh lifecycle (106)
Replace the connection/favorites ScrollView refreshable modifier with a locally owned UIRefreshControl attached through an inert content anchor to its ancestor scroll view. The asynchronous action ends the indicator explicitly on completion. Detaching the view cancels pending work, ends refreshing and removes only the owned control, preventing a stale spinner when a remote session replaces Home. Downward bounce and normal refresh behavior remain available. No refresh timers, delays, network changes or new dependencies. Regression surface: connection/favorites pull-to-refresh lifecycle; repeated pull and tab-return UI checks cover indicator disappearance. The prior screenshot's physical-device residual still needs user confirmation after installation.

### Window-isolated connections, URL launch and Home Screen shortcuts (107)
Enable UIApplicationSupportsMultipleScenes and register swiftrust:// alongside the legacy rustdesk ID-fill scheme. Each scene constructs a model with its persistent session identifier. NativeCoreChannel carries that window identifier through native JSON dispatch and the new rd_ios_take_window_frame ABI. Rust stores per-window session/event/frame state; event and decoded-frame callbacks locate the owning session, input/terminal/file/resolution commands resolve only within the request channel, and closing/releasing a window leaves other sessions intact. The default empty channel preserves the existing ABI/test callers. Request context is thread-local and restored after dispatch; state is synchronized by per-window mutexes and the registry mutex. Frame queues remain bounded to one pending frame per window. No Flutter runtime, transport protocol or dependency changes.

Terminal tabs and file jobs inherit their model channel, canvas text/mouse/frame access uses it, and resolution queue jobs preserve both channel and expected session UUID. Camera/terminal/HUD safe-area fallbacks resolve their own window rather than the globally first key window. Idle prevention aggregates connected models; Tailscale uses a single shared app node/controller because its persisted node directory and route are process-wide. Scene disconnect closes only its model and releases UI references. In-memory background recovery remembers the window's own last successful peer/mode, avoiding the other window's most recent global launch record. Fresh-launch restoration retains the existing separate opt-in setting.

Device menus offer New Window connection modes only when UIKit reports supportsMultipleScenes. Settings offers a new window action and a URL Scheme guide reporting system capability. NativeWindowLaunch requests a new scene with a typed NSUserActivity; explicit new-window activity is consumed once by the destination scene. The OS controls scene placement and availability; physical Duo side-by-side placement and two real peer sessions have not been validated. Unsupported systems show an error for newWindow links rather than replacing an existing session.

swiftrust://connect supports id, mode (desktop/terminal/files/camera), relay, approval, connect and newWindow. Parsers reject credentials in authority, unknown/duplicate parameters, invalid booleans/modes, empty/control-containing IDs, fragments and unexpected paths. It never accepts passwords/Auth keys, executes terminal commands, transfers files automatically or silently replaces an active connection. Connection/authentication follows the normal route. URL templates round-trip IPv6/port encoding. The iOS 17+ App Intent Connect Device hands off through the same validated custom-URL route using foreground UIApplication.open; it does not use OpenURLIntent (which expects universal links). App Shortcuts exposes the action in Shortcuts. Actual system-intent execution and Home Screen installation still need device validation.

The Add to Home Screen device sheet configures launch mode/relay/new window, copies the link, accepts a user-selected PhotosPicker image and exports PNG (or the existing device badge), and guides the user through Apple's Shortcuts/Add to Home Screen flow. iOS requires the user's final Add action; the app does not silently install profiles or use private icon-install APIs. Image export stays in a uniquely named local temporary file. No new third-party packages or upload service.
Regression surface: Rust iOS native registry/routing/ABI, Swift model/canvas/session dispatch, scene lifecycle/window creation, shortcut intent metadata, launch parser/router, device menu/settings and static language templates. Tests passed for malformed/encoded URL parsing, independent concurrent native connection channels, cross-channel resolution rejection, independent disconnect and per-window background recovery, URL help visibility, existing connect/disconnect and terminal rendering/tab isolation. Tests use loopback closed ports, never send commands to real hosts and do not establish two authorized remote desktop streams.

### On-device Web Clip generation and Safari download (108)
NativeDeviceLauncher now defaults to a local Web Clip workflow: editable Home Screen name, existing device badge or PhotosPicker image, 180-pixel square PNG generation, unsigned .mobileconfig export and short-lived local download. The profile contains exactly one com.apple.webClip.managed payload with Label, embedded Icon, the validated swiftrust launch URL and IsRemovable=true. The configuration remains removable and contains no MDM enrollment, VPN, certificate, credentials or other payloads. No signing key or developer account is required to generate it. The user must allow Safari's profile download and manually install in Settings; the app never confirms system profile installation. Existing Shortcuts/PNG export remains a secondary option.

NativeWebClipDownload binds only 127.0.0.1 on an ephemeral TCP port, with a random download path. It serves the current profile for GET/HEAD only, rejects other paths/methods, disables response caching, bounds request/header size and connection count, cancels connections after five seconds and stops after 45 seconds or OS background-task expiration. A finite UIKit background task lets the foreground app hand the file to the browser. No continuous background mode, public website, network-interface listener or remote upload. The downloaded profile embeds the swiftrust URL, never the temporary loopback URL, so installed icons do not depend on the listener/app staying alive.

Opening an HTTP link uses the system default browser; UI tells users to use Safari and exposes a Copy Local Download Link fallback for other defaults. Expired links can be regenerated. Privacy wording and URL documentation reflect local temporary image/profile storage. Regression surface: new NativeWebClip profile/loopback service, launcher form/download handoff, project source registration, privacy and fixed language templates. Tests passed for XML payload count/type/removability/name/embedded icon/URL, 180px icon encoding, invalid profile name rejection, byte-exact loopback response/MIME and unknown-path rejection. Build passes. Physical iOS profile installation and Web Clip-to-custom-scheme launch still require device testing; no successful installation or Home Screen icon launch is claimed.

### Background recovery requires an active session at background entry (109)
SceneDelegate now captures background eligibility only when the scene's model is connected with a valid session ID. Foreground recovery consumes that one-time peer/mode snapshot and never falls back to saved connection history from Home. Normal/user disconnect clears the snapshot; only the OS/background-timeout close preserves it. Returning with a healthy live connection is a no-op, and failed retained sessions must match the snapshot before retrying. Fresh-launch restoration remains separately controlled by native.launch-restore.
Regression surface: NativeShellModel background snapshot/reconnect/close, SceneDelegate didEnterBackground and timed close. Existing tests pass for Home/history not connecting, all four modes recovering after background close, healthy sessions left alone, explicit disconnect canceling recovery, disabled/one-time recovery, independent cold-launch preference and per-window isolation. No transport, timers, input or profile generation changes.

### Native shortcut handoff and remove Web Clip (109, final scope)
Removed NativeWebClip.swift, its Xcode build reference, generator, loopback listener/background download, profile export controls, profile-specific privacy text and tests. No Web Clip generation is retained in production sources. Previously installed iOS profiles/icons are outside the app sandbox and must be removed by the user in system Settings.

NativeConnectDeviceIntent now hands the validated typed request directly to the foreground/inactive UIWindowScene's SceneDelegate/model, rather than opening swiftrust through UIApplication.open. Its openAppWhenRun flag brings the app forward; connection authentication remains unchanged, active connections are not replaced and explicit newWindow still uses the existing scene launcher. This avoids Safari custom-scheme confirmation for the native action. Third-party URL scheme callers retain their normal system URL behavior; the app cannot suppress Safari's confirmation for old Web Clips. TargetApplicationBundleIdentifier is not added to a manual profile because Apple's documentation restricts it to MDM deployment.

The device launcher offers the public INUIAddVoiceShortcutViewController with an INShortcut based on a configured NSUserActivity (device URL/mode/relay/new-window/title already supplied). The user confirms the system add flow. This adds a configured system/Siri shortcut action, not an silently installed arbitrary .shortcut workflow file; adding a Home Screen icon/custom photo remains a system Shortcuts action. The existing App Intents Connect Device action remains available for native workflows. No signing server or private import API. Exported default device badge scale increases from 6x to 8x in the same 512-point image, increasing the central graphic by one third without changing card/list icons.
Regression surface: NativeLaunchLinks intent handoff/system shortcut representable/activity metadata/icon export, SceneDelegate typed handoff, removed profile build/source/UI/privacy path and language templates. Tests pass for configured activity payload/title/flags, executing the actual native Connect Device intent against a foreground test scene and closed loopback port, and tightened background recovery. The integration test activates the scene before invocation; no external command/real peer is used. End-user Siri/Shortcuts addition and Home Screen launch still need physical-device confirmation.

### Open Shortcuts directly without voice recording (110)
Remove INUIAddVoiceShortcutViewController, its delegate/SwiftUI sheet, the NSUserActivity suggestion builder and Intents/IntentsUI imports. The launcher button now builds the existing NativeConnectDeviceIntent with selected ID/mode/relay/new-window values, donates it through the public App Intents API and opens shortcuts:// directly. It never executes the intent while preparing it. Donation errors remain visible in the launcher and do not prevent attempting to open Shortcuts; an absent/unopenable Shortcuts app reports an error. UI accurately describes action preparation rather than claiming a workflow was silently saved. Final workflow creation/parameter confirmation and Home Screen addition remain inside the system Shortcuts app. No recording, microphone permission, voice phrase, browser/profile service or signing server.
Regression surface: NativeLaunchLinks launcher state/button/text, NativeDeviceShortcut configured intent builder, fixed language templates and build metadata. Tests pass for ID/mode/relay/new-window configuration and the actual native intent handoff into the app scene without a browser. Build passes; Shortcuts donation/ranking and end-user workflow-save UI need device confirmation. Previous tightened background recovery and larger exported device icons remain unchanged.

### Import actual signed shortcut workflows (111)
Remove the donation/open-shortcuts action and its misleading prepared-success state. The device launcher now copies the selected device ID to a local-only clipboard item (10-minute expiry) and presents an actual signed .shortcut file through UIActivityViewController, with a Files-save/open fallback. It does not mark a workflow added merely because the share sheet or Shortcuts opens. The user answers the import question by pasting the ID, then confirms Add Shortcut in the system importer. Home Screen addition and icon choice remain normal Shortcuts actions. No Siri recording, Web Clip or Safari runtime handoff.

Bundle 16 generic signed templates (four connection modes × relay on/off × new-window on/off). Each contains one NativeConnectDeviceIntent action, fixed selected mode/flags and an import-time ID question. No device IDs/credentials are embedded. Export selects the matching variant and copies bytes unchanged under a sanitized user-visible filename in a unique temporary directory; modifying parameter bytes after signing would invalidate the signature. NativeShortcutTemplates and the Xcode folder resource reference implement this path. scripts/ios/build-shortcut-templates.py contains all editable source and invokes Apple's public macOS shortcuts sign --mode anyone tool. Apple receives the placeholder-only template for validation, never the user's selected remote ID. No external signing service, third-party runtime package or on-phone signer.

Observed verification: Apple's macOS Shortcuts Import accepted a signed native template and displayed Add Shortcut; the preview was closed without adding it to the user's Mac library. All variants passed bundled AEA-header/presence and byte-identical export checks; the native Connect Device action still passed foreground-scene execution against a closed loopback port. Actual iOS sharing/import/ID-question/action-recognition still needs physical-device validation; this is not equivalent to having observed a successful Duo import. The simulator lacks the full Shortcuts app.
Regression surface: NativeLaunchLinks export/clipboard/share UI and template lookup, signed resource folder/project registration, new optional macOS template build script, language templates and build metadata. Native transport, background recovery, canvas/input and larger icon export are unchanged.

### Per-peer video cursor compatibility and metadata handling (112)
The reported immediate local pointer plus delayed second pointer is consistent with a pointer already present in the host video alongside the native predictive overlay, but the MacBook capture output has not been inspected directly. Do not guess from Mac hostnames or disable cursors on all Macs. Add Use Cursor in Video (Current Device) to the control-mode menu and connected pointer settings. It hides only the native overlay, leaves mouse input and protocol cursor subscription unchanged and persists under a peer-specific preference loaded on connect. Other peers retain their own/default selection. Video cursor size/latency remain controlled by the host/video stream; this cannot remove a baked cursor from a frame or make it independently resizeable.

NativeDisplay.cursorEmbedded accepts the native number/boolean forms and string 0/1/true/false variants. Peer info uses the decoder, and a partial switch_display preserves the prior embedded-cursor state when absent/invalid instead of resetting false. NativeShellModel.drawLocalCursor consolidates existing connected/show-remote-cursor/input-mode/display checks and the new per-peer override, consumed by the single CALayer cursor renderer.
Regression surface: NativeShellModel connect/embedded display parse/per-peer pointer preference, NativeDisplay flag decoder, NativeCanvasView cursor visibility and control/pointer settings UI. Tests pass for supported metadata representations, partial display state retention, actual pointer-layer hide/show, separate peer preference restoration and existing zoom-independent pointer size. No capture backend, remote Mac binary, input speed, network protocol or Rust changes. Actual MacBook-versus-MacMini behavior requires remote testing; the override is an explicit compatibility option, not automatic pixel-based embedded-cursor detection.

### Home screen quick actions and pointer restore (113)
Home screen long press exposes Add Window, Scan to Connect and Configure Common Devices, plus one common-device entry (direct for one device, chooser for several). Common devices store ID/name/mode/relay, default to a new scene and never replace an active session on systems without multiwindow support. Explicit actions cancel pending background recovery. Settings includes common-device configuration. Simulator tests passed for menu composition/routing, foreground recovery and actual SpringBoard menu opening the configuration page; physical simultaneous peer streams remain unverified.
The manual per-peer video-cursor override from 112 was removed at user request. Original adjustable local pointer behavior and embedded-cursor metadata handling remain. Removing the MacBook cursor already present in video is deferred at user request. Existing zoom-independent pointer size test passed.
Regression surface: native quick-action registration and scene routing, common-device settings/store, launch activities, cancellation after Tailscale preparation and native cursor visibility settings. No transport or Rust changes.

### Space-grouped remote IDs
Numeric IDs such as `1 694 351 955` normalize to `1694351955` before connection, launch-link validation and App Intent dispatch. Unicode whitespace used in copied numeric IDs is accepted. Non-numeric host/IP/port strings retain internal characters and existing URL validation. Regression surface: NativeLaunchLink normalization and NativeShellModel connect entry only; no Rust or protocol changes. Targeted tests cover grouped ID/link input and existing URL safety/IPv6 round trips.

### Direct common-device home quick actions
Each selected common device now registers its own stable ID-based Home Screen quick action, with device name and ID. Device actions precede utility actions; UIKit determines the displayed subset based on available space, following Apple's dynamic quick-action sample. Selecting a device resolves that exact saved device and preserves its mode/relay/new-window behavior. Removed the intermediate common-device picker and its sheet case; configuration remains available in Settings. Unknown or removed device actions fail without connecting to another device.
Regression surface: native quick-action item generation/dispatch, removed picker/sheet, settings explanatory text and language resource. No connection transport, scene lifecycle or saved-device format changes. Targeted tests cover two separately named menu entries and routing each to its own session without a selection sheet.

Desktop-menu configuration is now named 桌面菜单设备. Identity is the pair of remote ID and connection mode, allowing the same host to expose separate terminal/desktop/file/camera actions. Each recent peer expands into independent mode toggles; removal and relay preferences apply to that single menu entry. Existing saved entries remain decodable without migration. Tests passed for distinct same-host action types/subtitles and independent file/terminal routing.

### Full-screen QR connection scanner
Scanner presentation moves from the shared navigation sheet to a dedicated full-screen cover backed by the same NativeSheet selection. The camera fills the window; a centered rounded-square opening and dimmed surroundings define the visible scan area. VisionKit regionOfInterest uses the same view-coordinate rectangle and updates with window size; system guidance/highlights are disabled to avoid overlapping frames. Close remains accessible, permission/unavailable states stay visible, and successful scan uses a compact centered connection card. QR decoding/connection authorization are unchanged.
Regression surface: NativeShellView modal binding, NativeQRConnectionView layout and NativeQRScanner region updates. Pure geometry tests cover external/narrow, expanded and landscape windows; simulator cannot verify live camera recognition. No new dependencies or capture backend changes.

Verification: centered-region and existing QR decoding tests passed. Existing home navigation UI test passed with full-screen scanner presentation, accessible close action, return to Home and subsequent account/settings navigation. Camera recognition itself requires physical-device validation.

### Scanner close-button safe area (116)
Only the camera/reticle layer ignores safe areas. The title, close button and feedback remain in a sibling overlay that uses SwiftUI's live safe area on all edges. Removed the manual top/bottom window-inset workaround, which did not respect Duo's side exclusion area. The camera scan rectangle stays centered in the full window.
Regression surface: NativeQRConnectionView camera/header layout only. The existing scanner navigation UI test now rotates to landscape and checks the close button is hittable and inset from the display's right edge before closing. Physical Duo camera/cutout placement still needs user visual confirmation.

### Saved-device destructive confirmations (116)
NativePeerRow uses one optional confirmation value and one alert presenter for rename, record removal and password clearing, replacing three stacked alert modifiers. Each confirmation dispatches the existing synchronous peer command; cancellation does nothing. Storage behavior was verified against an isolated peer TOML fixture using the real Rust bridge: saved password becomes absent after refresh and removal deletes the file and refreshed row. No Rust or config format changes.
Regression surface: row confirmation state/presentation only. An isolated simulator UI fixture exercises the menu, clear-password confirmation/disabled state, remove-record confirmation and absence after relaunch; no real saved peer is deleted by tests.

Verification: the real-storage unit test and isolated destructive-menu UI flow both passed (no skips). The scanner navigation/landscape close-button safe-area test also passed.

### Public repository entry preparation
SwiftRustRepositoryURL points to the project repository and is shown in Settings → About and Open Source. It is separate from SwiftRustSourceURL, which remains empty until matching complete source is published. NOTICE/README and the local landing page include the project link without presenting an empty repository as a completed source release. Regression surface: native About/Open Source link UI and bundle metadata only; no session or input paths changed.

Verification: bundled repository/source URL assertions passed. Open Source UI test passed with repository links in Settings/About and the declaration page, pending-source notice, AGPL text and full third-party document navigation. No repository link is presented as a published version-matched source archive.

### Remote directory responsiveness (117)
Large file_dir payloads are decoded and naturally sorted on a detached user-initiated task. The main actor only publishes the completed directory. Reset cancels the pending application task, so closing a session cannot repopulate its cleared file browser. Duplicate directory requests and actions using the previous path are disabled while a directory is loading. Existing directory-first ordering and natural numeric filename order are preserved.
Directory-read errors use protocol job ID 0. These now finish loading and display the remote error rather than being discarded by the positive active-transfer-job guard. Malformed directory responses also finish loading with a retry message. The existing refresh button becomes usable again. Transfer job error routing is unchanged. A sync_peer_info update in an already connected file session no longer reloads the home directory.
Regression surface: NativeFileModel directory decode/loading/error/reset paths and file-screen action availability in NativeDeviceSessions.swift; the file-session peer-info initial-load branch in NativeShellModel.swift. No Rust, transport, filesystem wire format, terminal or desktop input changes. Tests use a synthetic 10,000-file listing, directory failures/malformed data and connected peer-info refresh. This is not a real network performance measurement; remote filesystem/permission/network latency still applies, and silent remote non-response is not bounded by a new timeout.

Verification: all three targeted native regression tests passed, including the synthetic 10,000-file listing and natural ordering, directory error recovery/malformed payload handling, and prevention of repeated home reload on sync_peer_info. No physical remote filesystem latency measurement was taken.

### Build 118 — OS password and file toolbar
Native control access menus and session settings expose a secure per-peer OS-password and auto-login editor. Saving uses upstream peer-option storage; sending explicitly invokes upstream password input. Secrets are loaded only when opening the editor, never in polling snapshots or UserDefaults, and cleared on dismissal. Automatic login preserves the upstream lock-after-session-end requirement. Stale-session writes, fixed settings and unauthorized sends are rejected before mutation. Simulator regression verifies rejected requests leave options unchanged; no live-host password input is tested.
Regression surface: ios_native.rs adds isolated native commands; NativeShellModel/NativeShellView route the editor; NativeSettingsView adds native entries and secure editor. NativeDeviceSessions moves parent navigation beside upload and changes upload to a tray symbol; directory and transfer behavior remain unchanged by this toolbar adjustment.

### Build 119 — responsive upload preparation
NativeDeviceSessions performs security-scoped, coordinated document copying in a detached background task rather than synchronously on the UI actor. Preparation exposes busy/cancel state, captures the destination before copying, and cancellation/reset prevents late completion from starting a transfer in another session. Failed preparation releases busy state and reports the error. Upstream transfer protocol is unchanged. The parent-directory toolbar symbol is now arrow.turn.up.left. Regression test verifies staged bytes, immediate UI yield, cancellation and missing-source recovery. Cloud-provider and real remote throughput require device validation.

### Build 120 — downloaded file card and listing identity
NativeDeviceSessions separates positive-job-ID transfer file lists from directory browsing responses, preventing downloaded-file paths and empty transfer entry names from replacing the current directory. Loading state is owned by directory requests rather than transfer metadata. Downloaded files receive a separate card with filename, completion indicator and bordered system share action. Remote filename gets explicit flexible width. Regression tests verify positive-job listings preserve directory/path and large directory parsing remains asynchronous. Shared Rust transfer handling is unchanged.

### Build 121 — root and settings navigation chrome
NativeShellView removes the custom settings-to-home back toolbar and preserves the native tab bar across all three root pages. NativeShellView owns the settings navigation path and hides the Dock when that path is nonempty. NativeSettingsView uses typed routes for its fourteen existing destinations, keeping their content and bindings intact. This avoids lifecycle/toolbar preference races and keeps the Dock hidden through nested legal pages, restoring it at the root. Regression UI coverage navigates settings, privacy, nested license pages and returns through the Dock to home. No remote session or transfer paths are changed.

### Build 122 — upload document picker fallback
The reported blank screen is the system document picker's Recents page, before file selection and upload preparation. NativeDeviceSessions replaces SwiftUI fileImporter with a stable UIDocumentPickerViewController representable in a sheet, starts browsing at the local Documents directory and supplies an independent cancel header. Delegate selection retains security-scoped, off-main preparation. Two simulator tests cover real picker creation/default directory/cancel and preparation/cancel/error recovery. This bypasses the Recents default and ensures an exit; it does not prove a system FileProvider service fault is repaired. Real Duo/Air provider behavior requires device confirmation. Regression surface is only the file upload selection presentation; shared Rust and session navigation are unchanged.

### Build 123 — compact OS-password popup and quick send
NativeSettingsView removes the access-menu password icon, replaces the password Form with the same compact glass surface as pointer controls, and adds a key-symbol quick-send action immediately above disconnect. NativeShellModel reads per-peer settings on demand and reuses the guarded save/send command; empty saved passwords open the editor. NativeImmersiveSessionView hosts the popup without a full-height sheet. Popup flags are cleared when opening another adjustment or ending a session. Existing password storage, permissions and auto-login semantics are unchanged; regression covers empty-password fallback/close and stale-session/unauthorized-send rejection. No password is sent to a live host during tests.

### Build 124 — native upload presentation and download manager
Build 123's password popup/quick-send changes are included. NativeDeviceSessions replaces nested document-picker embedding with presentation from the current UIWindow root/top controller, letting UIKit adapt bounds and safe areas. A real presentation regression waits for the FileProvider controller to attach and verifies its bounds fit the window. It does not prove real-device provider listing failures are eliminated.
Downloads are now managed in NativeDownloadsView, available from file toolbar and settings. It scans app Documents/Downloads off-main, shows active progress, shares/deletes completed local files, and excludes new incomplete downloads using a marker. Existing downloads remain discoverable. File taps open the manager; directory browsing can continue during a download. A file-session back action minimizes an active download to home, where manager/return-to-files actions remain available. Starting another session or disconnecting still cancels the single active transfer; separate windows have separate sessions. SceneDelegate requests the existing finite iOS background execution period for active downloads rather than applying the normal shorter disconnect preference. Expiration still disconnects; no indefinite background daemon, relaunch recovery or transfer queue is claimed. Info.plist permits opening shared Documents files in place.
Regression surface: NativeDeviceSessions selection/download model and UI; NativeShellModel minimized-file state; NativeShellView home/manager routing; NativeSettingsView manager entry; SceneDelegate active-download background timing; Info.plist document access. Rust protocol and core are unchanged. Tests cover persisted completed files, exclusion of incomplete files, deletion, native picker presentation bounds, password fallback, and background upload preparation.

### Build 125 — duplicate downloads and document-provider registration
Duo crash reports at 17:05 and 17:24 show com.apple.DocumentManager.Service terminated by a 10-second scene-update watchdog while FILocalAppContainerCollection resolves document nodes/default save location. This evidence points to the local system document service, not remote directory permission refresh. Info.plist disables UISupportsDocumentBrowser, UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace: SwiftRust is not a document browser/provider, and core configuration shares the private Documents root. Files remain shareable through download management. This is a targeted registration mitigation; device validation is still needed and no system-wide FileProvider repair is claimed. Diagnostic crash files stay outside the repository.
NativeDeviceSessions persists non-secret per-download source metadata (peer, full remote path, size and modification time), scans completed records off-main before creating a transfer, and reuses a matching intact local file. File size is checked on disk; no content hash is claimed. Legacy files without source metadata are preserved but are not guessed to match based on filename alone. Cancel/reset cancels lookup; incomplete downloads and source metadata are excluded from the manager list. Regression covers actual persisted duplicate reuse, completed/partial records, deletion and native picker presentation. Runtime changes are limited to download startup/directory modification-time decoding and app document registration; Rust transport and remote permission handling remain unchanged.

### Build 126 — multiselect and recursive queued downloads
NativeDeviceSessions adds selection/all-select, batch downloads and a download context menu for remote files and folders. Requests capture peer/path at selection, run sequentially in download management, reuse completed single-file records and skip already queued/current requests. Folder records retain type; folder content is re-fetched rather than trusting only the parent mtime. Hidden files are included for recursive transfers. Empty-directory responses are separately mapped beneath the new local download root, reject traversal/symlink escapes, and must finish before the incomplete marker is removed. Missing empty-directory responses stop the batch after 20 seconds and report incomplete rather than silently dropping empty folders.
Rust ios_native fileTransfer only adds directory/hidden forwarding and the existing remote empty-directory request; no new protocol or server behavior. NativeShellModel forwards empty_dirs to the browser. Tests pin batch snapshot paths/record reuse, completed/partial records/deletion, and empty directory structure/path validation. Real-host recursive transfer is not exercised by tests.
Remote deletion is deliberately absent: the user required the remote OS trash and declined a companion remote update. The stock file protocol only provides permanent removal, so no removal command or destructive remote button is wired. Local download-copy deletion remains local. Regression surface is selection/download UI and task sequencing, empty-directory event routing, and native-only FFI arguments; upload, remote desktop and terminal paths are unchanged.

### Build 127 — confirmed remote deletion and separate access actions
The user explicitly authorized permanent remote deletion after clarification. NativeDeviceSessions replaces selection's all-select text with download/delete icons and adds context-menu deletion for files/folders. A single alert route handles deletion confirmation and overwrite prompts without competing alert modifiers. Confirmation captures session and full remote paths, states item count/permanence, and never invokes deletion before the destructive action is tapped. Sequential folder removal lists hidden contents, validates every descendant path, removes files with acknowledged indices, then removes empty directories and releases the core removal job. Errors halt remaining actions and remain visible; stop only prevents remaining deletions. Deletion is blocked during loading/transfers; ordinary browsing cannot interrupt deletion enumeration.
Native-only ios_native fileDelete validates explicit confirmation, session token, non-root/non-traversing paths and file-operation permission, then calls existing RustDesk operations. No new protocol/server or FRB codegen. NativeShellModel exposes its current token for confirmation snapshots. NativeSettingsView's Access menu contains separate text-only Send OS Password and Auto Login actions, with no duplicate action above disconnect. Sending directly uses the saved password and opens no editor; missing credentials produce a configuration error. Auto Login retains the compact glass editor. Sending omits autoLogin so the native command leaves that option unchanged.
Tests cover confirmation/stale-session/root rejection and descendant safety without sending removal to a real host; missing-password send opens no editor; UI verifies separate Access actions and no duplicate quick-send action; existing batch-download regression passes. Real remote deletion must be validated by an intentional user-confirmed operation. Regression surface: native file model/UI and native-only command, password UI/model/command, plus read-only session-token exposure. No real remote files were removed during agent testing.

### Build 128 — separated selection actions
NativeDeviceSessions selection actions use equal-width bordered Download/Delete labels with icons and a 16-point gap; selection count moves above the buttons. Blue download and red deletion tints remain distinct. This is a reversible UI-only change; action handlers, confirmation and transfer/deletion state are unchanged. Validated by device compilation and signing, without redundant logic tests.

### Build 129 — download-manager selection and sound/access label
NativeDownloadsView adds local-file/folder multiselection with selection count and a fixed bottom bordered Delete action. A count-specific confirmation describes irreversible deletion of local copies. NativeFileModel's separate async batch method snapshots selected completed records, removes them off-main, retains unselected files, clears stale share references and displays per-file failures. Existing individual swipe deletion remains unchanged; controls avoid overlapping batch deletion. NativeSettingsView restores the parent Sound & Access menu label and speaker.wave.2 icon, while Send OS Password and Auto Login remain separate text-only child actions. Tests cover actual selected/unselected local files/folders and the restored menu's child actions. No remote deletion or transfer path is changed.

## Optional App Store support

Added NativeTipJar / StoreKit 2, with four consumable tips and no feature gating. The settings entry and launch transaction listener are enabled only by SWIFTRUST_APPSTORE in the external App Store signing build. SceneDelegate adds only this conditional startup hook; existing session paths are unchanged. NativeSettingsView adds one route; the privacy page adds a conditional Apple-payment disclosure. Product IDs, local test fixture and configuration steps are documented in docs/swiftrust/IN_APP_SUPPORT.md. No financial credentials are included.

Validation: ARM64 iOS Simulator build with SWIFTRUST_APPSTORE passed. The first generic simulator build attempted unsupported x86_64 native libraries; ARM64 destination succeeds. Payment testing was interrupted at an unexpected Apple-account prompt; no credentials supplied and no live purchase completed. StoreKit fixture retained for explicit local/sandbox validation; payment flow is not marked verified.

Public contact links: Settings/About and the optional support page open the user-approved feedback mailbox and X profile. Privacy/contact also offers the mailbox. Mail opens a composer; SwiftRust does not send feedback automatically or attach logs.

About links: GitHub uses its official vector mark and X follow is a separate external-profile entry, not a feedback channel. Both rows use matching neutral rounded icon tiles and external-link arrows, adapting to appearance. Brand asset provenance is in docs/swiftrust/BRAND_ASSETS.md. No network calls occur until a link is opened.

Open-source notice UI is now fixed English regardless of app language: grouped project/terminal/network/dependency rows, copyright and license summary cards, original selectable text, export and existing 16k-character paging. Original license resources remain unchanged. This affects only legal navigation and document presentation; source availability warnings and combined dependency notices remain accessible.

Notice layout validation: testLicensePagesPreserveEntireDocumentAndUnicode passed; testOpenSourcePageShowsLocalLicenseAndPendingSource passed after updating UI selectors for English component rows. The latter verifies AGPL detail, original notice text, paging, export and return navigation in the simulator.

Home project menu: a dedicated trailing information button opens support (App Store builds), feedback, configured App Store review and Settings/About. NativeShellView owns settings path and the About request; NativeSettingsView scrolls to its About section on explicit requests only. Existing remote session paths and other settings destinations remain unchanged. Support uses a red filled heart.

Validation: App Store-flagged ARM64 simulator build passed; testHomeProjectMenuOpensSettingsAboutSection passed, confirming the menu navigates to the visible version and open-source rows without manual scrolling.

Home layout correction: removed the trailing safeAreaInset that reduced connection-card and peer-row width. Project menu now overlays the existing window trailing safe-area rail when present; normal narrow windows float it above the bottom Dock. The overlay uses this model’s own UIWindow, preserving separate multiwindow layouts. Existing content padding is restored.

Floating project button clarification: the control remains independent of the connection card on every device. Air uses a bottom-trailing overlay with clearance above the bottom Dock; windows with a system trailing status rail place it below that status area. iOS 26+ uses native interactive Liquid Glass, with a material fallback on older systems. No safe-area inset is added and existing card spacing is preserved.

Home title bar: added a scroll-content SwiftRust heading aligned to the card edge. Air places the existing project menu on its trailing edge; both scroll away naturally. A minimal 64pt scroll allowance permits this with an otherwise short history. Favorites remain unchanged. Duo’s menu uses a trailing-safe-area-width frame with its midpoint aligned to the current window’s system side rail; no extra content column is reserved and system Dock/status elements are not redrawn.

Title hiding uses the scroll geometry’s top-relative content offset on iOS 18+, hiding the full header after 24pt rather than leaving a partial title; iOS 17 keeps normal scroll-away behavior. The visibility update only occurs when the threshold boolean changes. Simulator regression test passed for full-width input, title visible → hidden on upward scroll → visible on return, and About navigation. Duo’s system rail alignment still requires visual checking on the physical device.

Support page compaction: one short headline, four tips in a two-column grid, compact inline status/retry and contact links, short voluntary/TestFlight disclosure. Accessibility text sizes use a single column and scrolling remains available rather than clipping. No StoreKit transaction or pricing behavior changed.

Duo rail optical correction: the supplied Build 134 screenshot places the information glyph about 12 screenshot pixels to the right of the system Dock icon. Applied a 6pt leading correction to the existing side-rail overlay only. Air title-bar placement, Dock and content widths remain unchanged.

Native home navigation replaces the earlier custom header/side overlay: NavigationStack owns the SwiftRust large title and a topBarTrailing Menu. Removed side-inset estimates, 6pt optical offset, fixed Y coordinate, manual glass surface, extra minimum scroll height and scroll-threshold state. iOS now decides placement and large-title collapse. Favorites retain a hidden navigation bar; Settings navigation and the system TabView Dock are unchanged.

Support layout preference: four compact vertical rows (icon, title, localized price) replace the two-column grid. Short copy, small spacing and existing scrolling/accessibility remain; purchase behavior is unchanged.

Privacy disclosure revision: distinguishes absence of developer-operated collection/backend from required device/service traffic, local storage, optional Tailscale/Apple services, permissions, retention and deletion controls. Voluntary email feedback is explicitly separate and supports deletion requests. Matching English translations and docs/swiftrust/PRIVACY.md are supplied. No networking or data-retention implementation changed. App Store-flagged simulator build and English coverage checks passed.

Formal notice revision: SwiftRust and RustDesk have separate attribution entries and concise resource files, each accompanied by the full AGPL license. Original source copyrights and notices remain authoritative. Added explicit brand-mark attribution and an additional-component review. Replaced the manual license pager/UITextView with one ScrollView/LazyVStack of selectable 16k-character chunks, loaded off-main. Removed generated audit commentary from display resources only, preserving original legal text and detailed audit files. License continuity and UI scrolling/export/back tests passed. No session or purchase runtime paths changed.

Support identity: Albert avatar and localized developer name; GitHub, X and email use matching 48×44pt rounded icon buttons with accessibility labels. Notice navigation omits the brand group and unconfigured source-download row, retaining repository links and bundled notices. Only support/notice presentation changed; purchase and session behavior are unchanged.

Support contact placement: GitHub, X and email icon buttons now follow the developer name in the identity row rather than appearing below the tips. Button dimensions, destinations and purchase behavior are unchanged.

Support identity-row sizing: contact tiles reduced to 36×36pt with 18pt icons and 8pt spacing to keep the developer row compact. Link destinations and transaction behavior remain unchanged.
