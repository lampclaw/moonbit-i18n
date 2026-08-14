# Runtime SPI

[English](runtime-spi.mbt.md)

本文面向生成器、框架和工具维护者。普通应用应使用自身生成的 i18n package，不应
直接导入 runtime package。

## Package 边界

- `lampclaw/i18n/runtime` 提供 catalog 解析、locale 查找、可移植 MF2 compiler、
  pattern selection、parts formatting、fallback 和诊断。
- `lampclaw/i18n/runtime/js` 提供 JavaScript `Intl` formatter 及其有界 cache。
- 生成的应用 package 依赖二者，并对外暴露应用自己的类型。

SPI 之所以是 public，只是因为生成 package 与 runtime 位于不同 MoonBit package；
public 可见性并不代表它是应用 authoring 接口。

## 编译与格式化

`compile_mf2_message(source, contract)` 校验源码并返回 `CompiledMessage`。catalog
安装会先编译全部 entry，再提交 catalog，因此正常查找不会重复解析消息文本。

`format_text` 与 `format_parts` 接收编译结果。parts 以 `Text`、`Open`、`Close`、
`Standalone` 输出；text 格式化遇到 markup 会失败，避免把 tag 意外拍平成不安全字符
串。旧的 `format_mf2_message` 与 `format_mf2_rich` wrapper 仍供底层兼容，但每次调用
都会重新编译。

formatter callback 返回带 `FormatterIssue` 的 `Result`。JS adapter 会捕获 `Intl`
构造和执行异常，转换成 `InvalidFormatterOption` 或 `PlatformFormatterFailure`，因此
JavaScript 异常不会穿过 formatter 边界。

独立 standards-core 路径先调用 `parse_valid_mf2_model`，再调用
`format_mf2_model_standalone`，也可以直接使用 `format_mf2_standalone`。它的
`Mf2FormatResult` 会同时返回 best-effort 文本、不绑定 renderer 的 structured part 与
已发现的 typed error。`Mf2FormattingContext` 要求严格 BCP 47 locale，以及显式的
value/message 方向 metadata。使用 `unicode-mf2-ldml48.2-js-v1` 的 catalog-v2 entry
会在原子安装期间一次解析为该 model，再通过固定默认 registry 格式化。Compatibility
catalog 继续使用 `CompiledMessage`；详见
[`mf2-resolution-formatting.zh-CN.mbt.md`](mf2-resolution-formatting.zh-CN.mbt.md)。

Node 26 JavaScript 上，`@runtime_js.format_mf2` 提供固定 stable 默认 registry 与
structured `Intl` field。Framework 可以取得 `@runtime_js.mf2_registry()`，注册
`Mf2FunctionHandler`，再调用 `@runtime.format_mf2`。Custom function 必须带 namespace，
且不计入 Unicode conformance；见
[`mf2-default-functions.zh-CN.mbt.md`](mf2-default-functions.zh-CN.mbt.md)。

## Catalog 兼容契约

`0.8.0` 接受 catalog format version `2`，profile 可以是 compatibility
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1`，也可以是 standards authoring
`unicode-mf2-ldml48.2-js-v1`。一个 `I18n` 实例只要求其中一个精确 profile，不能混合
catalog。`contractHash` 是规范 UTF-8 契约的 SHA-256；该契约覆盖所选 profile、消息
ID、参数类型与允许的 markup。只有版本、profile、contract hash 和归一化 locale
全部匹配时才会接受 catalog。

解析与安装均有硬上限：JSON 源码和内嵌消息数据各 16 MiB、每个 catalog 100,000
条消息、每条消息 64 KiB、每个编译消息 4,096 个 declaration 和 4,096 个 variant。
安装先构造完整编译 map，所有 entry 成功后才会修改 runtime 状态。
生成器配置另外限制为最多 1,000 个 locale、合计 64 MiB UTF-8 locale 输入和
64 MiB 生成 MoonBit 源码；每个生成消息签名最多包含 64 个参数和 64 个声明的
rich-part tag。底层 formatter 最多接受 64 个参数，每个 expression 或 markup
元素最多包含 64 个 option。

## 有意使用的底层命名

- `Catalog::from_generated_entries(...)` 从生成器拥有的数据创建内嵌 catalog。
- `I18n::install_generated_catalog(...)` 安装这些内嵌 catalog。
- `Translator::translate_raw(...)` 接收字符串 ID 与原始消息参数，供兼容 adapter 使用。
- `Translator::try_t(...)` 和 `try_t_parts(...)` 保留结构化 `TranslationError`；
  `t(...)` 和 `t_parts(...)` 是有损的便捷路径。
- `parse_catalog(...)` 和 catalog source 安装能力供生成的懒加载 adapter 使用。

应用快速上手文档不应展示这些接口，也不应让用户构造 `CatalogEntry`、`MessageArg`、
`MessageValue` 或 `MessageContract`；这些转换应由生成 facade 完成。

## Fallback 与诊断

查找会依次尝试请求 locale chain，最后尝试配置的 fallback。某个 catalog 格式化失败
不会中断链路，后续 catalog 仍可返回有效消息；若所有候选均失败，`try_t` 会返回失败
候选关联的全部格式化错误。

runtime 在有界、去重的 buffer 中记录消息缺失、逐消息 fallback 和格式化失败，默认
容量为 256。每条记录有出现次数，`DiagnosticBatch.dropped` 表示未能保留的不同诊断
数量。`take_diagnostics()` 会取出并清空 buffer。

## Profile 边界

Compatibility profile 保留 pattern、declaration、matcher、legacy markup part、
`:string`、`:number`、`:integer`、`:offset` 与私有 `:lampclaw:datetime`。Standards
authoring profile 使用完整固定 model、resolution、bidi、stable 默认 registry，以及
单独标记的 draft date/time function。生成的 standards catalog 会拒绝所有 private 或
custom function。底层调用者仍可注册带 namespace 的 custom function，但其行为不属于
生成 authoring 与 conformance。两个 profile 名称都不提前声明最终 1.0 完整 Unicode
MF2 契约；固定参考快照与兼容矩阵见
[`mf2-profile.zh-CN.mbt.md`](mf2-profile.zh-CN.mbt.md)。
