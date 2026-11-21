# 46 项许可证证据核查

核查日期：2026-11-20。**40 项已补充或澄清，6 项仍需核实原始通知或授权范围。** 这 46 项原本是“没有找到根目录许可文件”的扫描结果，不代表 46 个许可证冲突。

核查依据为本次 iOS 构建所用 Cargo.lock、发布包 `.cargo_vcs_info.json`、包校验和、上游固定提交及原始许可文本。实际 iOS 依赖链通过 `cargo metadata --features flutter --filter-platform aarch64-apple-ios` 的 root 节点递归计算；依赖图包含构建期组件，不代表每项都进入最终 App 的链接结果。

| 组件 | 声明许可 | iOS 依赖链 | 结果 | 原文或声明证据 |
|---|---|---|---|---|
| alloc-stdlib 0.2.2 | BSD-3-Clause | 不在本次 root 依赖链 | 已补上游原文 | [证据](license-evidence/alloc-stdlib/LICENSE) |
| asn1-rs-impl 0.2.0 | MIT/Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/asn1-rs-impl/LICENSE-APACHE) |
| async-compression 0.4.32 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/async-compression/LICENSE-APACHE) |
| base 0.1.0 | Cargo 未单独声明 | 包含 | 按所属主项目许可 | [证据](license-evidence/base/RustDesk-LICENCE.txt) |
| clipboard 0.1.0 | Cargo 未单独声明 | 不在本次 root 依赖链 | 按所属主项目许可 | [证据](license-evidence/clipboard/RustDesk-LICENCE.txt) |
| compression-codecs 0.4.31 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/compression-codecs/LICENSE-APACHE) |
| compression-core 0.4.29 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/compression-core/LICENSE-APACHE) |
| crc-catalog 2.4.0 | MIT OR Apache-2.0 | 包含 | 原包已有，修正漏报 | [证据](license-evidence/crc-catalog/LICENSES__Apache-2.0.txt) |
| dart-sys 4.1.5 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dart-sys/LICENSE-APACHE-2.0.md) |
| dasp 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp/LICENSE-APACHE) |
| dasp_envelope 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_envelope/LICENSE-APACHE) |
| dasp_frame 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_frame/LICENSE-APACHE) |
| dasp_interpolate 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_interpolate/LICENSE-APACHE) |
| dasp_peak 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_peak/LICENSE-APACHE) |
| dasp_ring_buffer 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_ring_buffer/LICENSE-APACHE) |
| dasp_rms 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_rms/LICENSE-APACHE) |
| dasp_sample 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_sample/LICENSE-APACHE) |
| dasp_signal 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_signal/LICENSE-APACHE) |
| dasp_slice 0.11.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_slice/LICENSE-APACHE) |
| dasp_window 0.11.1 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/dasp_window/LICENSE-APACHE) |
| dlopen_derive 0.1.4 | MIT | 包含 | 源码一致后补原文 | [证据](license-evidence/dlopen_derive/LICENSE) |
| dylib_virtual_display 0.1.0 | Cargo 未单独声明 | 不在本次 root 依赖链 | 按所属主项目许可 | [证据](license-evidence/dylib_virtual_display/RustDesk-LICENCE.txt) |
| enum-map 2.7.3 | MIT OR Apache-2.0 | 包含 | 原包已有，修正漏报 | [证据](license-evidence/enum-map/LICENSES__Apache-2.0.txt) |
| enum-map-derive 0.17.0 | MIT OR Apache-2.0 | 包含 | 原包已有，修正漏报 | [证据](license-evidence/enum-map-derive/LICENSES__Apache-2.0.txt) |
| flutter_rust_bridge 1.80.1 | MIT | 包含 | 已补上游原文 | [证据](license-evidence/flutter_rust_bridge/LICENSE) |
| flutter_rust_bridge_macros 1.82.6 | MIT | 包含 | 已补上游原文 | [证据](license-evidence/flutter_rust_bridge_macros/LICENSE) |
| fon 0.6.0 | Apache-2.0 OR MIT OR BSL-1.0 | 包含 | 已补上游原文 | [证据](license-evidence/fon/LICENSE_APACHE_2_0.txt) |
| hbb_common 0.1.0 | Cargo 未单独声明 | 包含 | 待上游声明核实 | [证据](license-evidence/hbb_common/PACKAGE-MANIFEST.toml) |
| phf 0.7.24 | MIT | 包含 | 已补上游原文 | [证据](license-evidence/phf/LICENSE) |
| phf_codegen 0.7.24 | MIT | 包含 | 已补上游原文 | [证据](license-evidence/phf_codegen/LICENSE) |
| phf_generator 0.7.24 | MIT | 包含 | 已补上游原文 | [证据](license-evidence/phf_generator/LICENSE) |
| phf_shared 0.7.24 | MIT | 包含 | 已补上游原文 | [证据](license-evidence/phf_shared/LICENSE) |
| quest 0.3.0 | MIT | 包含 | 待上游声明核实 | [证据](license-evidence/quest/PACKAGE-MANIFEST.toml) |
| remote_printer 0.1.0 | Cargo 未单独声明 | 不在本次 root 依赖链 | 按所属主项目许可 | [证据](license-evidence/remote_printer/RustDesk-LICENCE.txt) |
| repng 0.2.2 | MIT | 包含 | 待上游声明核实 | [证据](license-evidence/repng/PACKAGE-MANIFEST.toml) |
| rustdesk-portable-packer 1.5.3 | Cargo 未单独声明 | 不在本次 root 依赖链 | 按所属主项目许可 | [证据](license-evidence/rustdesk-portable-packer/RustDesk-LICENCE.txt) |
| scrap 0.5.0 | MIT | 包含 | 待上游声明核实 | [证据](license-evidence/scrap/PACKAGE-MANIFEST.toml) |
| stunclient 0.4.1 | MIT/Apache-2.0 | 包含 | 待上游声明核实 | [证据](license-evidence/stunclient/PACKAGE-MANIFEST.toml) |
| system-configuration 0.5.1 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/system-configuration/LICENSE-APACHE) |
| system-configuration-sys 0.5.0 | MIT OR Apache-2.0 | 包含 | 源码一致后补原文 | [证据](license-evidence/system-configuration-sys/LICENSE-APACHE) |
| target_build_utils 0.3.1 | ISC/Apache-2.0 | 包含 | 待上游声明核实 | [证据](license-evidence/target_build_utils/PACKAGE-MANIFEST.toml) |
| virtual_display 0.1.0 | Cargo 未单独声明 | 不在本次 root 依赖链 | 按所属主项目许可 | [证据](license-evidence/virtual_display/RustDesk-LICENCE.txt) |
| webm 1.1.0 | MPL-2.0 | 包含 | 已核对，保留 MPL 条件 | [证据](license-evidence/webm/MPL-2.0.txt) |
| webm-sys 1.0.4 | MPL-2.0 | 包含 | 已核对，保留 MPL 条件 | [证据](license-evidence/webm-sys/MPL-2.0.txt) |
| webrtc 0.13.0 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/webrtc/LICENSE-APACHE) |
| yasna 0.5.2 | MIT OR Apache-2.0 | 包含 | 已补上游原文 | [证据](license-evidence/yasna/LICENSE-APACHE) |

## 逐项结论与来源

### alloc-stdlib 0.2.2

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/dropbox/rust-alloc-no-stdlib/6032b6a9b20e03737135c55a0270ccffcc1438ef/LICENSE](https://raw.githubusercontent.com/dropbox/rust-alloc-no-stdlib/6032b6a9b20e03737135c55a0270ccffcc1438ef/LICENSE)；保存为 [LICENSE](license-evidence/alloc-stdlib/LICENSE)。SHA-256：`c0c56f26d9c051cac4d200c34c84e7ae9aaa853e01a982a1df08b09931e518ae`。

### asn1-rs-impl 0.2.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rusticata/asn1-rs/a20e5f7319c896737ad0f2557037817b91ad854f/LICENSE-APACHE](https://raw.githubusercontent.com/rusticata/asn1-rs/a20e5f7319c896737ad0f2557037817b91ad854f/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/asn1-rs-impl/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/rusticata/asn1-rs/a20e5f7319c896737ad0f2557037817b91ad854f/LICENSE-MIT](https://raw.githubusercontent.com/rusticata/asn1-rs/a20e5f7319c896737ad0f2557037817b91ad854f/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/asn1-rs-impl/LICENSE-MIT)。SHA-256：`a5c61b93b6ee1d104af9920cf020ff3c7efe818e31fe562c72261847a728f513`。

### async-compression 0.4.32

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-APACHE](https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/async-compression/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-MIT](https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/async-compression/LICENSE-MIT)。SHA-256：`88d1e3160df48926ad3310a8ec5699b502889565908f1be7e77cd21282c7a709`。

### base 0.1.0

RustDesk 主仓库内模块，Cargo.toml 未单独声明 license；保留所属项目根目录 AGPL v3，不能把缺少每个 crate 的独立 LICENSE 误判为无许可证。此结论不覆盖另外的 Git 子模块或第三方代码。

- 原始来源：[https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE](https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE)；保存为 [RustDesk-LICENCE.txt](license-evidence/base/RustDesk-LICENCE.txt)。SHA-256：`8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef`。

### clipboard 0.1.0

RustDesk 主仓库内模块，Cargo.toml 未单独声明 license；保留所属项目根目录 AGPL v3，不能把缺少每个 crate 的独立 LICENSE 误判为无许可证。此结论不覆盖另外的 Git 子模块或第三方代码。

- 原始来源：[https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE](https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE)；保存为 [RustDesk-LICENCE.txt](license-evidence/clipboard/RustDesk-LICENCE.txt)。SHA-256：`8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef`。

### compression-codecs 0.4.31

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-APACHE](https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/compression-codecs/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-MIT](https://raw.githubusercontent.com/Nullus157/async-compression/b79f66d40697ab7dadf791a416ab2ba15cccc3a3/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/compression-codecs/LICENSE-MIT)。SHA-256：`88d1e3160df48926ad3310a8ec5699b502889565908f1be7e77cd21282c7a709`。

### compression-core 0.4.29

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/Nullus157/async-compression/44383cee94fec7276c0dc08dd73f8eb4a93b80ba/LICENSE-APACHE](https://raw.githubusercontent.com/Nullus157/async-compression/44383cee94fec7276c0dc08dd73f8eb4a93b80ba/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/compression-core/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/Nullus157/async-compression/44383cee94fec7276c0dc08dd73f8eb4a93b80ba/LICENSE-MIT](https://raw.githubusercontent.com/Nullus157/async-compression/44383cee94fec7276c0dc08dd73f8eb4a93b80ba/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/compression-core/LICENSE-MIT)。SHA-256：`88d1e3160df48926ad3310a8ec5699b502889565908f1be7e77cd21282c7a709`。

### crc-catalog 2.4.0

原发布包的 LICENSES/ 目录已有原文；初版扫描器只检查根目录文件而漏报。保留其 MIT、Apache 2.0 与存在的 CC0 文件。

- 原始来源：[https://docs.rs/crate/crc-catalog/2.4.0/source/LICENSES/Apache-2.0.txt](https://docs.rs/crate/crc-catalog/2.4.0/source/LICENSES/Apache-2.0.txt)；保存为 [LICENSES__Apache-2.0.txt](license-evidence/crc-catalog/LICENSES__Apache-2.0.txt)。SHA-256：`d3cdb764b98283ee7c3a3cea8d374e2a2957322374378d1f3263f4d512741fc3`。
- 原始来源：[https://docs.rs/crate/crc-catalog/2.4.0/source/LICENSES/MIT.txt](https://docs.rs/crate/crc-catalog/2.4.0/source/LICENSES/MIT.txt)；保存为 [LICENSES__MIT.txt](license-evidence/crc-catalog/LICENSES__MIT.txt)。SHA-256：`5ef8fcfb6cccec8fcae043c834099a60c8b7406408db576e026d2b7e67dc5cf5`。

### dart-sys 4.1.5

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。 同时保留嵌套 Dart SDK / 音频 stream 的 BSD 声明，外层 MIT/Apache 许可不能替代它。

- 原始来源：[https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/LICENSE-APACHE-2.0.md](https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/LICENSE-APACHE-2.0.md)；保存为 [LICENSE-APACHE-2.0.md](license-evidence/dart-sys/LICENSE-APACHE-2.0.md)。SHA-256：`9c7a58ef39c896d7cc48e18c0a38eb570fc7cecb15a656101d399e367da800a2`。
- 原始来源：[https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/LICENSE-MIT.md](https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/LICENSE-MIT.md)；保存为 [LICENSE-MIT.md](license-evidence/dart-sys/LICENSE-MIT.md)。SHA-256：`a6b742d988bc83c6182193ca4e5abf2dbb67e929817fc94f5ed6e9f49b803f29`。
- 原始来源：[https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/LICENSE.md](https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/LICENSE.md)；保存为 [LICENSE.md](license-evidence/dart-sys/LICENSE.md)。SHA-256：`a8e681b06a00b38be7d345ffa7671b80f9ef770192b8c0522d5c839e31654de1`。
- 原始来源：[https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/dart-sys/dart-sdk/LICENSE](https://raw.githubusercontent.com/dart-sys/dart-sys/c9329430a5a8e3828cf59600babe7896326c7c44/dart-sys/dart-sdk/LICENSE)；保存为 [dart-sys__dart-sdk__LICENSE](license-evidence/dart-sys/dart-sys__dart-sdk__LICENSE)。SHA-256：`2cfa3ee8e7512e6d44c854b986510810fadc815f93f890373b3a81c1b6ccd256`。

### dasp 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_envelope 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_envelope/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_envelope/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_frame 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_frame/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_frame/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_interpolate 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_interpolate/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_interpolate/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_peak 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_peak/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_peak/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_ring_buffer 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_ring_buffer/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_ring_buffer/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_rms 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_rms/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_rms/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_sample 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/sample/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/sample/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_sample/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/sample/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/sample/97c3bb9b2363c0b46ac1633858bf1054fd02a980/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_sample/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_signal 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_signal/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_signal/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_slice 0.11.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_slice/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/221b81038c528bf3fc364a8ab5cc4b2e52f7dbfc/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_slice/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dasp_window 0.11.1

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/e4d535324f8b6c83d16c4f006a9ba3f07f3f147d/LICENSE-APACHE](https://raw.githubusercontent.com/rustaudio/dasp/e4d535324f8b6c83d16c4f006a9ba3f07f3f147d/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/dasp_window/LICENSE-APACHE)。SHA-256：`756c8d2ab2dc24f256e1455b5f03937f4933d83d7bc9f2d55009fc962377d512`。
- 原始来源：[https://raw.githubusercontent.com/rustaudio/dasp/e4d535324f8b6c83d16c4f006a9ba3f07f3f147d/LICENSE-MIT](https://raw.githubusercontent.com/rustaudio/dasp/e4d535324f8b6c83d16c4f006a9ba3f07f3f147d/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/dasp_window/LICENSE-MIT)。SHA-256：`b1d6df41ed3aa96806e74c729444d7c121d90e6660a6aed01d298e03fde475a0`。

### dlopen_derive 0.1.4

原发布记录缺少可访问的精确源码提交，已对比另一上游提交中的全部 5 个 Rust 源文件（包含 build.rs 如有），逐字节相同，再从该仓库根目录补回许可证；不是直接套用最新版声明。

- 原始来源：[https://raw.githubusercontent.com/szymonwieloch/rust-dlopen/26b70292744db1052403378d4a01075b6171e3d1/LICENSE](https://raw.githubusercontent.com/szymonwieloch/rust-dlopen/26b70292744db1052403378d4a01075b6171e3d1/LICENSE)；保存为 [LICENSE](license-evidence/dlopen_derive/LICENSE)。SHA-256：`062e40ee707f6ab1ca0955624ccfa78d666250a2e821f892705f455cf70dc28a`。

### dylib_virtual_display 0.1.0

RustDesk 主仓库内模块，Cargo.toml 未单独声明 license；保留所属项目根目录 AGPL v3，不能把缺少每个 crate 的独立 LICENSE 误判为无许可证。此结论不覆盖另外的 Git 子模块或第三方代码。

- 原始来源：[https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE](https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE)；保存为 [RustDesk-LICENCE.txt](license-evidence/dylib_virtual_display/RustDesk-LICENCE.txt)。SHA-256：`8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef`。

### enum-map 2.7.3

原发布包的 LICENSES/ 目录已有原文；初版扫描器只检查根目录文件而漏报。保留其 MIT、Apache 2.0 与存在的 CC0 文件。

- 原始来源：[https://docs.rs/crate/enum-map/2.7.3/source/LICENSES/Apache-2.0.txt](https://docs.rs/crate/enum-map/2.7.3/source/LICENSES/Apache-2.0.txt)；保存为 [LICENSES__Apache-2.0.txt](license-evidence/enum-map/LICENSES__Apache-2.0.txt)。SHA-256：`074e6e32c86a4c0ef8b3ed25b721ca23aca83df277cd88106ef7177c354615ff`。
- 原始来源：[https://docs.rs/crate/enum-map/2.7.3/source/LICENSES/CC0-1.0.txt](https://docs.rs/crate/enum-map/2.7.3/source/LICENSES/CC0-1.0.txt)；保存为 [LICENSES__CC0-1.0.txt](license-evidence/enum-map/LICENSES__CC0-1.0.txt)。SHA-256：`a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`。
- 原始来源：[https://docs.rs/crate/enum-map/2.7.3/source/LICENSES/MIT.txt](https://docs.rs/crate/enum-map/2.7.3/source/LICENSES/MIT.txt)；保存为 [LICENSES__MIT.txt](license-evidence/enum-map/LICENSES__MIT.txt)。SHA-256：`b85dcd3e453d05982552c52b5fc9e0bdd6d23c6f8e844b984a88af32570b0cc0`。

### enum-map-derive 0.17.0

原发布包的 LICENSES/ 目录已有原文；初版扫描器只检查根目录文件而漏报。保留其 MIT、Apache 2.0 与存在的 CC0 文件。

- 原始来源：[https://docs.rs/crate/enum-map-derive/0.17.0/source/LICENSES/Apache-2.0.txt](https://docs.rs/crate/enum-map-derive/0.17.0/source/LICENSES/Apache-2.0.txt)；保存为 [LICENSES__Apache-2.0.txt](license-evidence/enum-map-derive/LICENSES__Apache-2.0.txt)。SHA-256：`074e6e32c86a4c0ef8b3ed25b721ca23aca83df277cd88106ef7177c354615ff`。
- 原始来源：[https://docs.rs/crate/enum-map-derive/0.17.0/source/LICENSES/CC0-1.0.txt](https://docs.rs/crate/enum-map-derive/0.17.0/source/LICENSES/CC0-1.0.txt)；保存为 [LICENSES__CC0-1.0.txt](license-evidence/enum-map-derive/LICENSES__CC0-1.0.txt)。SHA-256：`a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`。
- 原始来源：[https://docs.rs/crate/enum-map-derive/0.17.0/source/LICENSES/MIT.txt](https://docs.rs/crate/enum-map-derive/0.17.0/source/LICENSES/MIT.txt)；保存为 [LICENSES__MIT.txt](license-evidence/enum-map-derive/LICENSES__MIT.txt)。SHA-256：`b85dcd3e453d05982552c52b5fc9e0bdd6d23c6f8e844b984a88af32570b0cc0`。

### flutter_rust_bridge 1.80.1

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/fzyzcjy/flutter_rust_bridge/9904bc6ce4a9433c035141d931f7bc69c83655ab/LICENSE](https://raw.githubusercontent.com/fzyzcjy/flutter_rust_bridge/9904bc6ce4a9433c035141d931f7bc69c83655ab/LICENSE)；保存为 [LICENSE](license-evidence/flutter_rust_bridge/LICENSE)。SHA-256：`d56622df159a9967bd6a16c726823a2cbe8546c1f18437617283c9da27000390`。

### flutter_rust_bridge_macros 1.82.6

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/fzyzcjy/flutter_rust_bridge/1a5b35a45b7ddca36abfa2294174fc26e1806b36/LICENSE](https://raw.githubusercontent.com/fzyzcjy/flutter_rust_bridge/1a5b35a45b7ddca36abfa2294174fc26e1806b36/LICENSE)；保存为 [LICENSE](license-evidence/flutter_rust_bridge_macros/LICENSE)。SHA-256：`d56622df159a9967bd6a16c726823a2cbe8546c1f18437617283c9da27000390`。

### fon 0.6.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。 同时保留嵌套 Dart SDK / 音频 stream 的 BSD 声明，外层 MIT/Apache 许可不能替代它。

- 原始来源：[https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/LICENSE_APACHE_2_0.txt](https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/LICENSE_APACHE_2_0.txt)；保存为 [LICENSE_APACHE_2_0.txt](license-evidence/fon/LICENSE_APACHE_2_0.txt)。SHA-256：`62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a`。
- 原始来源：[https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/LICENSE_BOOST_1_0.txt](https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/LICENSE_BOOST_1_0.txt)；保存为 [LICENSE_BOOST_1_0.txt](license-evidence/fon/LICENSE_BOOST_1_0.txt)。SHA-256：`c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566`。
- 原始来源：[https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/LICENSE_MIT.txt](https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/LICENSE_MIT.txt)；保存为 [LICENSE_MIT.txt](license-evidence/fon/LICENSE_MIT.txt)。SHA-256：`508a77d2e7b51d98adeed32648ad124b7b30241a8e70b2e72c99f92d8e5874d1`。
- 原始来源：[https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/src/stream/LICENSE.BSD-3](https://raw.githubusercontent.com/ardaku/fon/0da249a64100e3eb8574aafa4308e938f1660285/src/stream/LICENSE.BSD-3)；保存为 [src__stream__LICENSE.BSD-3](license-evidence/fon/src__stream__LICENSE.BSD-3)。SHA-256：`671bb5d8fd3c6b05a2e831d90f978ac27965c92bd8ea6d16b3df76e3440c0e9f`。

### hbb_common 0.1.0

独立 Git 子模块 fae47e024dd83cef6aaecde0aa7d11731df11649 的根目录与 Cargo.toml 均未提供明确许可证。不能仅因它位于 RustDesk 项目目录就替上游授权；需要核实该提交的授权范围或取得维护者说明。

- 未按缺少证据推断为未授权，也未按 Cargo 中的简写声明伪造作者的版权年份或原始许可文件。

### phf 0.7.24

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/sfackler/rust-phf/1287414b1302d2d717c5f4be81accf4c12ccad48/LICENSE](https://raw.githubusercontent.com/sfackler/rust-phf/1287414b1302d2d717c5f4be81accf4c12ccad48/LICENSE)；保存为 [LICENSE](license-evidence/phf/LICENSE)。SHA-256：`d8870d5e2ab20fc50915b711c5aa7588131c9abcc1bcb980da1efd7486522a46`。

### phf_codegen 0.7.24

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/sfackler/rust-phf/e235374a7c11721ed7313977c89d5b75ad38c840/LICENSE](https://raw.githubusercontent.com/sfackler/rust-phf/e235374a7c11721ed7313977c89d5b75ad38c840/LICENSE)；保存为 [LICENSE](license-evidence/phf_codegen/LICENSE)。SHA-256：`d8870d5e2ab20fc50915b711c5aa7588131c9abcc1bcb980da1efd7486522a46`。

### phf_generator 0.7.24

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/sfackler/rust-phf/e235374a7c11721ed7313977c89d5b75ad38c840/LICENSE](https://raw.githubusercontent.com/sfackler/rust-phf/e235374a7c11721ed7313977c89d5b75ad38c840/LICENSE)；保存为 [LICENSE](license-evidence/phf_generator/LICENSE)。SHA-256：`d8870d5e2ab20fc50915b711c5aa7588131c9abcc1bcb980da1efd7486522a46`。

### phf_shared 0.7.24

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/sfackler/rust-phf/e235374a7c11721ed7313977c89d5b75ad38c840/LICENSE](https://raw.githubusercontent.com/sfackler/rust-phf/e235374a7c11721ed7313977c89d5b75ad38c840/LICENSE)；保存为 [LICENSE](license-evidence/phf_shared/LICENSE)。SHA-256：`d8870d5e2ab20fc50915b711c5aa7588131c9abcc1bcb980da1efd7486522a46`。

### quest 0.3.0

发布包 Cargo.toml 声明 MIT，但未带 LICENSE/版权通知，原 quadrupleslap/quest 上游仓库目前返回 404。保留元数据证据；尚未找回该发布版本的原始许可通知，不编造年份或版权人。

- 未按缺少证据推断为未授权，也未按 Cargo 中的简写声明伪造作者的版权年份或原始许可文件。

### remote_printer 0.1.0

RustDesk 主仓库内模块，Cargo.toml 未单独声明 license；保留所属项目根目录 AGPL v3，不能把缺少每个 crate 的独立 LICENSE 误判为无许可证。此结论不覆盖另外的 Git 子模块或第三方代码。

- 原始来源：[https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE](https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE)；保存为 [RustDesk-LICENCE.txt](license-evidence/remote_printer/RustDesk-LICENCE.txt)。SHA-256：`8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef`。

### repng 0.2.2

发布包 Cargo.toml 声明 MIT，但未带 LICENSE/版权通知，原 quadrupleslap/repng 上游仓库目前返回 404。保留元数据证据；尚未找回该发布版本的原始许可通知，不编造年份或版权人。

- 未按缺少证据推断为未授权，也未按 Cargo 中的简写声明伪造作者的版权年份或原始许可文件。

### rustdesk-portable-packer 1.5.3

RustDesk 主仓库内模块，Cargo.toml 未单独声明 license；保留所属项目根目录 AGPL v3，不能把缺少每个 crate 的独立 LICENSE 误判为无许可证。此结论不覆盖另外的 Git 子模块或第三方代码。

- 原始来源：[https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE](https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE)；保存为 [RustDesk-LICENCE.txt](license-evidence/rustdesk-portable-packer/RustDesk-LICENCE.txt)。SHA-256：`8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef`。

### scrap 0.5.0

RustDesk 内的 fork 的 Cargo.toml 声明 MIT，README 明确源自 quadrupleslap/scrap。原上游当前快照也未附独立 LICENSE。不能用 RustDesk 根 AGPL 替代其继承的 MIT 通知；需核实/补回原始版权许可通知。

- 未按缺少证据推断为未授权，也未按 Cargo 中的简写声明伪造作者的版权年份或原始许可文件。

### stunclient 0.4.1

锁定提交 ef35ef84347ce3a504c0f159c6b46c3e3234ecc5 的 Cargo.toml 声明 MIT/Apache-2.0，但根目录及源码树未找到独立许可通知。许可证选择已知，原始版权通知仍需核对；未擅自为作者生成许可声明。

- 未按缺少证据推断为未授权，也未按 Cargo 中的简写声明伪造作者的版权年份或原始许可文件。

### system-configuration 0.5.1

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-APACHE](https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/system-configuration/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-MIT](https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/system-configuration/LICENSE-MIT)。SHA-256：`35b228510156c3d7bf94b129c81b7e3cc72d347586e632be15686232b342562a`。

### system-configuration-sys 0.5.0

原发布记录缺少可访问的精确源码提交，已对比另一上游提交中的全部 8 个 Rust 源文件（包含 build.rs 如有），逐字节相同，再从该仓库根目录补回许可证；不是直接套用最新版声明。

- 原始来源：[https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-APACHE](https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/system-configuration-sys/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-MIT](https://raw.githubusercontent.com/mullvad/system-configuration-rs/56e415eb24b0897bef96a9a38fe7883cfbe2bb94/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/system-configuration-sys/LICENSE-MIT)。SHA-256：`35b228510156c3d7bf94b129c81b7e3cc72d347586e632be15686232b342562a`。

### target_build_utils 0.3.1

发布包声明 ISC/Apache-2.0；README 的 License 段却称 llvm_build_utils。当前上游亦未带许可文件。需核实这段引用是否适用于本包及应保留的原始版权许可通知。

- 未按缺少证据推断为未授权，也未按 Cargo 中的简写声明伪造作者的版权年份或原始许可文件。

### virtual_display 0.1.0

RustDesk 主仓库内模块，Cargo.toml 未单独声明 license；保留所属项目根目录 AGPL v3，不能把缺少每个 crate 的独立 LICENSE 误判为无许可证。此结论不覆盖另外的 Git 子模块或第三方代码。

- 原始来源：[https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE](https://github.com/rustdesk/rustdesk/blob/669cb8ac62aa20d3626395877d7dd0357aec7ed2/LICENCE)；保存为 [RustDesk-LICENCE.txt](license-evidence/virtual_display/RustDesk-LICENCE.txt)。SHA-256：`8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef`。

### webm 1.1.0

锁定提交的 Cargo.toml 明确声明 MPL-2.0；仓库未附 MPL 全文，已补 Mozilla 官方标准原文，并保留 libwebm 的 Google BSD 声明。检查锁定源码未发现 MPL 1.1 来源标记或 Exhibit B 二级许可排除声明。按 MPL 3.3 的条件与 AGPL v3 组合；保留 MPL 通知及适用源码取得方式，不把全部组件统一改写为 AGPL。后续升级需重查。

- 原始来源：[https://www.mozilla.org/media/MPL/2.0/index.815ca599c9df.txt](https://www.mozilla.org/media/MPL/2.0/index.815ca599c9df.txt)；保存为 [MPL-2.0.txt](license-evidence/webm/MPL-2.0.txt)。SHA-256：`fab3dd6bdab226f1c08630b1dd917e11fcb4ec5e1e020e2c16f83a0a13863e85`。
- 原始来源：[https://github.com/rustdesk-org/rust-webm/tree/d2c4d3ac133c7b0e4c0f656da710b48391981e64](https://github.com/rustdesk-org/rust-webm/tree/d2c4d3ac133c7b0e4c0f656da710b48391981e64)；保存为 [libwebm-LICENSE.TXT](license-evidence/webm/libwebm-LICENSE.TXT)。SHA-256：`5aec868f669e384a22372a4e8a1a6cd7d44c64cd451f960ca69cc170d1e13acf`。

### webm-sys 1.0.4

锁定提交的 Cargo.toml 明确声明 MPL-2.0；仓库未附 MPL 全文，已补 Mozilla 官方标准原文，并保留 libwebm 的 Google BSD 声明。检查锁定源码未发现 MPL 1.1 来源标记或 Exhibit B 二级许可排除声明。按 MPL 3.3 的条件与 AGPL v3 组合；保留 MPL 通知及适用源码取得方式，不把全部组件统一改写为 AGPL。后续升级需重查。

- 原始来源：[https://www.mozilla.org/media/MPL/2.0/index.815ca599c9df.txt](https://www.mozilla.org/media/MPL/2.0/index.815ca599c9df.txt)；保存为 [MPL-2.0.txt](license-evidence/webm-sys/MPL-2.0.txt)。SHA-256：`fab3dd6bdab226f1c08630b1dd917e11fcb4ec5e1e020e2c16f83a0a13863e85`。
- 原始来源：[https://github.com/rustdesk-org/rust-webm/tree/d2c4d3ac133c7b0e4c0f656da710b48391981e64](https://github.com/rustdesk-org/rust-webm/tree/d2c4d3ac133c7b0e4c0f656da710b48391981e64)；保存为 [libwebm-LICENSE.TXT](license-evidence/webm-sys/libwebm-LICENSE.TXT)。SHA-256：`5aec868f669e384a22372a4e8a1a6cd7d44c64cd451f960ca69cc170d1e13acf`。

### webrtc 0.13.0

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/rustdesk-org/webrtc/49c89bd8d30e6e62e4c1a96cee38fdc11f79ef63/LICENSE-APACHE](https://raw.githubusercontent.com/rustdesk-org/webrtc/49c89bd8d30e6e62e4c1a96cee38fdc11f79ef63/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/webrtc/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/rustdesk-org/webrtc/49c89bd8d30e6e62e4c1a96cee38fdc11f79ef63/LICENSE-MIT](https://raw.githubusercontent.com/rustdesk-org/webrtc/49c89bd8d30e6e62e4c1a96cee38fdc11f79ef63/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/webrtc/LICENSE-MIT)。SHA-256：`56cc6c08157f4faf70d351b3a7ceac143399d5359a78c180e06dcd0390784f4d`。

### yasna 0.5.2

许可证文本来自发布包 .cargo_vcs_info.json 指定的提交（Git 依赖则为 Cargo.lock 锁定提交），保留原文。

- 原始来源：[https://raw.githubusercontent.com/qnighy/yasna.rs/b7e65f9a4c317494cce2d18ea02b3d6eaaea7985/LICENSE-APACHE](https://raw.githubusercontent.com/qnighy/yasna.rs/b7e65f9a4c317494cce2d18ea02b3d6eaaea7985/LICENSE-APACHE)；保存为 [LICENSE-APACHE](license-evidence/yasna/LICENSE-APACHE)。SHA-256：`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`。
- 原始来源：[https://raw.githubusercontent.com/qnighy/yasna.rs/b7e65f9a4c317494cce2d18ea02b3d6eaaea7985/LICENSE-MIT](https://raw.githubusercontent.com/qnighy/yasna.rs/b7e65f9a4c317494cce2d18ea02b3d6eaaea7985/LICENSE-MIT)；保存为 [LICENSE-MIT](license-evidence/yasna/LICENSE-MIT)。SHA-256：`2a7df90e60fd5512b8bca35d3ce90e068f21c52d962855053fd1d9e2e7ca0f16`。

## 许可条件与发布边界

- MIT / BSD 等组件保留原作者通知和免责条款；双许可依赖保留取得的两份原文，不改成“所有第三方均为 AGPL”。
- 对 MPL-2.0 的 webm / webm-sys：锁定源码未发现二级许可排除标记，按 MPL 3.3 的条件处理 AGPL 组合，保留 MPL 源码及相关通知，并保留内部 libwebm 的 Google BSD 原文。许可证全文中自带的 Exhibit B 样本并不等于组件已选择该排除。
- 相关解释：[Mozilla MPL FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/)、[MPL 2.0 正文](https://www.mozilla.org/en-US/MPL/2.0/)、[GNU 许可证列表](https://www.gnu.org/licenses/license-list.html)、[Apache 官方兼容说明](https://apache.org/licenses/GPL-compatibility.html)。
- hbb_common 为独立子模块，不直接套用主项目根许可；这与 base 等主仓库内模块不同。
- 其余 407 项未在本轮重审范围内。没有因为它们带有 LICENSE 文件就宣称已完成全部代码来源、专利、许可证兼容性、二进制链接和完整对应源码审计。
- 源码云端入口仍未配置，依赖源码提供、版本一致性及发布方式仍按 RELEASING.md 处理。

## 可复核性

`LICENSE_AUDIT.json` 保存逐项版本、声明许可、包来源、发布包校验和、证据文件 SHA-256 及源码比对结果。`collect-notices.py` 在再生成时验证这些证据及包校验和；版本或源信息不匹配时拒绝沿用。元数据仅说明包的许可证声明，不能替代缺失的完整许可通知。
