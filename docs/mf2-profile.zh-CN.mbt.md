# MessageFormat profile

[English](mf2-profile.mbt.md)

`0.6.0` 刻意提供三个彼此独立的 profile：

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` 是已有应用使用的 catalog、
  generator、generated facade 与 formatting profile；
- `unicode-mf2-ldml48.2-syntax-v1` 解析和校验完整的固定 grammar 与规范
  interchange data model；
- `unicode-mf2-ldml48.2-resolution-v1` 在该 model 上增加 declaration/option
  resolution、matcher selection、best-effort fallback、structured output、Unicode bidi
  isolation 与严格 BCP 47 边界。

这种隔离避免标准能力悄悄改变现有 catalog 含义。Canonical JSON authoring 和 generated
application 继续使用 strict-v1；显式 catalog `messageProfile` 选择在 `0.8.x` 到来。独立
API 分别记录于[语法/data-model 指南](mf2-syntax-data-model.zh-CN.mbt.md)和
[resolution/formatting 指南](mf2-resolution-formatting.zh-CN.mbt.md)。

上游比较点是 Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027)，
日期为 2026-06-11，属于 LDML 48.2 时期。不可变 pin、vendored fixture、Unicode license
和机器可读矩阵位于 `tests/unicode-mf2/`。Locale canonicalization 另行固定到日期为
2026-08-08 的 IANA Language Subtag Registry。

## 兼容矩阵

| 领域 | 现有 catalog profile | Syntax profile | Resolution profile |
|---|---|---|---|
| Grammar | 严格、面向行的项目子集 | 完整固定 message ABNF | 相同完整固定 model |
| Validity | catalog compile/install 失败 | parse 与 validity 分层 | invalid model 返回整条 fallback 与 error |
| Declaration | eager strict-v1 binding | 保留在 interchange data | 按源码顺序、最多求值一次 |
| Selection | 项目 ranking 规则 | 保留但不执行 | 规范 Match/BetterThan 多 selector 算法 |
| 运行期错误 | 操作失败 | 不适用 | typed error、best-effort 输出与 fallback value |
| Markup | 平衡的 legacy rich part | 规范 open/close/standalone model | 保留 option/attribute 的惰性 structured event |
| NFC | 无完整 identifier/key normalization | name 与 duplicate detection | selector key normalization |
| Locale | 兼容下划线的 legacy normalization | 不适用 | 严格 RFC 5646 canonicalization 与 RFC 4647 lookup |
| Bidi | catalog direction metadata | 接受 syntax control | 默认 LRI/RLI/FSI/PDI 与 structured control |
| Function | 项目子集和私有 datetime | 只保留 reference | 在 `0.7.x` 稳定默认/公开 registry 前报告 unknown |

## Conformance 声明

当前版本只声明固定的 syntax、validity/data-model 和 resolution-core 能力。Vendored suite
在四个 MoonBit backend 上证明 114 个 well-formed syntax、133 个 syntax-error、23 个
data-model，以及 67 个 fallback、pattern-selection、bidi 与 Unicode-option 用例。

这不是完整 Unicode MessageFormat conformance 声明。稳定默认 function registry、
JavaScript `Intl`/CLDR provider、公开 custom registry 和完整 function fixture 属于
`0.7.x` 门槛。Catalog authoring profile 选择、私有 datetime 迁移、规范 requirement matrix
与 differential test 属于 `0.8.x` 门槛。

## 变更纪律

三个 identifier 都是公共兼容契约，legacy catalog identifier 还参与每个 catalog contract
hash。任何语义扩展或不兼容收紧，都必须改变相关 identifier，并在同一变更中同步 matrix、
固定 fixture、测试和中英文文档。CI 会校验生成 fixture test、固定 MF2 source、固定 IANA
registry、profile 声明与 archive 内容。
