# 支持与兼容政策

[English](support-policy.mbt.md)

本文档定义 `0.1.x` Web 基线的支持范围。只有在这里列出且由发布门槛持续验证的目标，
才属于受支持目标。

## 支持矩阵

| 界面 | 发布门槛 | 支持级别 |
|---|---|---|
| MoonBit 工具链 | archive `0.10.6+80dc50f24`、Moon `0.1.20260803`、moonc `0.10.6` | `0.1.x` 发布固定且必需 |
| JavaScript runtime | Node.js `26.7.0` | 唯一的服务端/runtime 与产品门槛 |
| 浏览器 runtime | 锁定 Playwright `1.62.1` 提供的 Chromium、Firefox、WebKit | 生成 facade 与应用场景 |
| CLI 操作系统 | Ubuntu 24.04、macOS 15、Windows 2025 | Wasm `moonx`、Native CLI 和安装 launcher |
| 可移植 core | Native、Wasm、Wasm-GC、JavaScript | 编译与目标无关行为 |
| locale-sensitive formatter | JavaScript | 使用宿主 `Intl` 的产品后端 |

Playwright engine 是可复现的浏览器契约，并不表示支持基于这些 engine 的每一个品牌
浏览器版本。Native、Wasm 与 Wasm-GC 的 locale-sensitive formatting 仍然有限，
不属于 JavaScript 产品 conformance 声明。

## `0.x` 兼容性

- release candidate 应精确固定版本。为修正发布契约，`0.1.0-rc.N` 可以包含已经记录的
  源码破坏。
- `0.1.0` 之后，`0.1.x` patch 默认保持已经记录的公共 API 与生成源码兼容。安全修复
  可以立即拒绝此前接受的不安全输入。
- 语义扩展或不兼容的收紧必须改变 message profile，并重新生成产物。只有 wire shape
  或 decoding contract 改变时才改变 catalog version。
- 生成源码、CLI 与库必须使用同一个精确版本；升级时必须重新生成并提交产物。
- 在 `1.0` 前，不可避免的公共破坏通常要在更早的 minor version 提供诊断与迁移路径。
  当前 strict-v1 profile 在整个 `0.1.x` 中保持冻结。

精确的已发布消息语法与语义由 [MF2 派生 profile](mf2-profile.zh-CN.mbt.md) 定义，
不能以路线图中的规划能力为准。
