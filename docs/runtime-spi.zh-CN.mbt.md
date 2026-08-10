# Runtime SPI

[English](runtime-spi.mbt.md)

本文面向生成器、框架和工具维护者。普通应用应使用自身生成的 i18n package，不应
直接导入 runtime package。

## Package 边界

- `lampclaw/i18n/runtime` 提供 catalog 解析、locale 查找、MF2 格式化、fallback
  和诊断。
- `lampclaw/i18n/runtime/js` 提供 JavaScript `Intl` formatter。
- 生成的应用 package 依赖二者，并对外暴露应用自己的类型。

SPI 之所以是 public，只是因为生成 package 与 runtime 位于不同 MoonBit package；
public 可见性并不代表它是应用 authoring 接口。

## 有意使用的底层命名

- `Catalog::from_generated_entries(...)` 从生成器拥有的数据创建内嵌 catalog。
- `I18n::install_generated_catalog(...)` 安装这些内嵌 catalog。
- `Translator::translate_raw(...)` 接收字符串 ID 与原始消息参数。
- `parse_catalog(...)` 和 catalog source 安装能力供生成的懒加载适配器使用。

这些名称明确表达了其集成用途。应用快速上手文档不应展示它们，也不应让用户构造
`CatalogEntry`、`MessageArg` 或 `MessageValue`。

## 兼容契约

在 `0.1.0` 开发阶段继续使用 catalog format version `1`。只有版本受支持、schema
hash 与运行契约一致，并且归一化 locale 与生成 facade 请求的类型化 locale 一致
时，catalog 才能安装。

当前 schema hash 对消息 ID 和参数类型做确定性 fingerprint；它还不是密码学 hash，
也尚未覆盖完整消息契约。

## 诊断

runtime 会记录消息缺失、逐消息 fallback 和格式化失败。生成 package 会把这些值
转换为自己的 `Diagnostic` 类型，因此应用代码无需依赖 runtime 的诊断构造器。

## 范围说明

basic formatter 仍用于 runtime 测试和非 JS SPI 使用者，但不提供完整 CLDR 行为。
本轮开发生成的 authoring facade 只支持 JS，并始终接入
`lampclaw/i18n/runtime/js`。
