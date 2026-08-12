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

## Catalog 兼容契约

`0.1.0-rc.2` 只接受精确的 catalog format version `2` 和 profile
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1`。`contractHash` 是规范 UTF-8 契约的
SHA-256；该契约覆盖 profile、消息 ID、参数类型与允许的 markup。只有版本、profile、
contract hash 和归一化 locale 全部匹配时才会接受 catalog。

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

稳定 profile 支持 pattern、declaration、matcher、markup parts、`:string`、
`:number`、`:integer` 与 `:offset`，并用项目扩展 `:lampclaw:datetime` 处理
`InstantMillis`。完整 CLDR plural/date 行为由 JS formatter 提供。可选 registry
function、bidi isolation、完整 BCP 47 canonicalization 和任意用户自定义 function
不属于该 profile，会被明确拒绝。
该名称刻意不宣称完整 Unicode MF2 合规；固定参考快照与兼容矩阵见
[`mf2-profile.zh-CN.mbt.md`](mf2-profile.zh-CN.mbt.md)。
