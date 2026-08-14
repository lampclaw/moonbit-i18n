# MessageFormat profile

[English](mf2-profile.mbt.md)

`0.7.0` 刻意提供四个彼此独立的 profile：

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` 是已有应用不变的 catalog、generator、
  generated-facade 与 formatting profile；
- `unicode-mf2-ldml48.2-syntax-v1` 覆盖完整固定 grammar 与规范 interchange data
  model；
- `unicode-mf2-ldml48.2-resolution-v1` 增加 declaration/option resolution、selection、
  fallback、structured output、bidi isolation 与严格 BCP 47；
- `unicode-mf2-ldml48.2-default-functions-v1` 增加 stable required 默认 registry 与
  公开 custom-function 边界。

分离这些契约可避免标准能力悄悄改变已有 catalog 含义。Canonical JSON authoring 与
generated application 仍使用 strict-v1；显式 catalog `messageProfile` 选择在 `0.8.x`
到来。

上游固定点是 Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027)，
日期为 2026-06-11，属于 LDML 48.2 时期。不可变 source、hash、fixture、Unicode license
和机器可读 profile 位于 `tests/unicode-mf2/`。Locale canonicalization 另行固定到
2026-08-08 的 IANA Language Subtag Registry。

## 兼容矩阵

| 领域 | 现有 catalog | Syntax | Resolution | 默认函数 |
|---|---|---|---|---|
| Grammar | 严格项目子集 | 完整固定 message ABNF | 相同 model | 相同 model |
| Validity | compile/install 失败 | parse 与 validity 分层 | 整条 fallback 加 error | function error；规范要求时保留可用 best-effort value |
| Declaration | eager strict-v1 | 保留 | 按源码顺序、最多一次 | typed value 与 option 继承 |
| Selection | 项目 ranking | 保留 | 规范 Match/BetterThan | string 与 numeric exact/plural/ordinal selector |
| Parts | legacy rich part | interchange data | 惰性 markup/option/attribute | expression part 中的宿主 number/date field |
| Unicode | legacy locale 兼容 | NFC name/duplicate | NFC key、bidi、严格 RFC 5646/4647 | JavaScript 上的 Node 26 Intl/CLDR 行为 |
| Function | 项目子集和私有 datetime | 只保留 reference | provider 边界 | stable required default，加单独标记的 draft date/time |
| Extension | 私有 catalog function | 不执行 | 无公开扩展 | 带 namespace、NFC-safe 的 custom registry，不计入 conformance |

详情见[语法/data-model 指南](mf2-syntax-data-model.zh-CN.mbt.md)、
[resolution 指南](mf2-resolution-formatting.zh-CN.mbt.md)与
[默认函数指南](mf2-default-functions.zh-CN.mbt.md)。

## Conformance 声明

JavaScript backend 声明固定版本的 syntax、validity/data-model、resolution core 与
stable required default-function 范围。证据包括：

- 114 个 well-formed syntax、133 个 syntax-error 和 23 个 data-model case；
- Native、JavaScript、Wasm 与 Wasm-GC 上的 67 个 fallback、pattern-selection、bidi
  和 Unicode-option case；
- Node 26 JavaScript 上全部 124 个固定 default-function case。

Stable 范围是 `:string`、`:number`、`:integer`、`:offset`、`:currency` 与
`:percent`。`:date`、`:time`、`:datetime` 因路线图要求而实现，但在固定规范中仍为
Draft，因此不计入 stable 声明。Draft `:unit` 暂缓。Native/Wasm CLDR 输出、catalog
profile 选择、私有 datetime 迁移、规范 requirement matrix 与独立 differential test
仍不属于 `0.7.0`。

因此 `0.7.0` 的 conformance surface 已显著扩大，但仍不声明完整 Unicode
MessageFormat conformance。

## 变更纪律

四个 identifier 都是兼容契约，legacy catalog identifier 还参与 catalog contract
hash。语义扩展或不兼容收紧必须在同一变更中更新 identifier、matrix、固定 source、
生成测试和中英文文档。CI 校验这些关系及发布 archive。
