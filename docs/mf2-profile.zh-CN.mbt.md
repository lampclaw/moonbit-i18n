# MessageFormat profile

[English](mf2-profile.mbt.md)

`0.8.0` 刻意提供五个彼此独立的 profile：

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` 是已有应用使用的 compatibility catalog
  profile；
- `unicode-mf2-ldml48.2-js-v1` 是 standards-mode authoring、generated facade、catalog
  与 Node 26 JavaScript runtime 的聚合 profile；
- `unicode-mf2-ldml48.2-syntax-v1` 覆盖完整固定 grammar 与规范 interchange data
  model；
- `unicode-mf2-ldml48.2-resolution-v1` 增加 declaration/option resolution、selection、
  fallback、structured output、bidi isolation 与严格 BCP 47；
- `unicode-mf2-ldml48.2-default-functions-v1` 增加 stable required 默认 registry 与
  公开 custom-function 边界。

分离这些契约可避免标准能力悄悄改变已有 catalog 含义。Canonical JSON config 现在会
显式选择 `messageProfile`；新 scaffold 与维护中的 Rabbita 应用使用
`unicode-mf2-ldml48.2-js-v1`。省略该字段会暂时选择 compatibility mode，并输出 warning
`I18N1003`。私有 `:lampclaw:datetime` 只被 compatibility profile 接受，standards mode
会拒绝它。详见[迁移指南](message-profile-migration.zh-CN.mbt.md)。

上游固定点是 Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027)，
日期为 2026-06-11，属于 LDML 48.2 时期。不可变 source、hash、fixture、Unicode license
和机器可读 profile 位于 `tests/unicode-mf2/`。Locale canonicalization 另行固定到
2026-08-08 的 IANA Language Subtag Registry。

## 兼容矩阵

| 领域 | Compatibility catalog | Standards generated catalog | Standalone standards core |
|---|---|---|---|
| Profile | `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` | `unicode-mf2-ldml48.2-js-v1` | 上述 syntax、resolution 与 default-registry identifier |
| Grammar/model | 严格项目子集 | 完整固定 message grammar 与 valid model | 公开 functional/JSON interchange model |
| Resolution | eager strict-v1 行为 | 按源码顺序 declaration、规范 selection/fallback/error | 相同行为，使用显式 formatting context |
| Parts/bidi | 平衡 legacy rich part | 兼容 `MessagePart` 投影与默认 Unicode isolation；field/attribute 使用 standalone core | 不绑定 renderer 的 structured output，保留 option、field、attribute、ID，并可控制 isolation |
| Function | 项目子集和私有 datetime | stable required default，加单独标记的 draft date/time | portable registry；Node 26 `Intl` provider 位于 `runtime/js` |
| Extension | 只有私有 datetime | generated authoring 不允许 private/custom function | 带 namespace 的 custom registry，不计入 conformance |
| Catalog identity | catalog v2 + profile 专属 contract hash | catalog v2 + profile 专属 contract hash | 不是部署格式 |

详情见[语法/data-model 指南](mf2-syntax-data-model.zh-CN.mbt.md)、
[resolution 指南](mf2-resolution-formatting.zh-CN.mbt.md)与
[默认函数指南](mf2-default-functions.zh-CN.mbt.md)。

## Conformance 声明

JavaScript backend 声明固定版本的 syntax、validity/data-model、resolution core 与
stable required default-function 范围。证据包括：

- 114 个 well-formed syntax、133 个 syntax-error 和 23 个 data-model case；
- Native、JavaScript、Wasm 与 Wasm-GC 上的 67 个 fallback、pattern-selection、bidi
  和 Unicode-option case；
- Node 26 JavaScript 上全部 124 个固定 default-function case；
- 经检查的 20 条 scope 内规范 requirement、全部 6 个 stable function 与 40 个 stable
  option，每一项都链接到可执行证据；
- 相对独立 `messageformat@4.0.0` 的 24 个 differential case：15 个输出逐字一致、2 个
  error/fallback 语义一致、7 个 CLDR-sensitive 输出一致。在 Node 26.7.0 上没有无法
  解释的 semantic failure，也没有观察到 CLDR 文本差异。

Stable 范围是 `:string`、`:number`、`:integer`、`:offset`、`:currency` 与
`:percent`。`:date`、`:time`、`:datetime` 因路线图要求而实现，但在固定规范中仍为
Draft，因此不计入 stable 声明。Draft `:unit` 暂缓。Native/Wasm CLDR 输出仍不属于
JavaScript 声明。`0.9.x` 仍需要为 1.0 选择并冻结精确的最新 stable Unicode/LDML
目标、在该固定目标运行完整受支持浏览器矩阵，并冻结公共契约。

因此 `0.8.0` 的 conformance surface 已显著扩大，但仍不声明完整 Unicode
MessageFormat conformance。

## 变更纪律

五个 identifier 都是兼容契约。所选 compatibility 或 standards authoring identifier
会参与 catalog contract hash。语义扩展或不兼容收紧必须在同一变更中更新 identifier、
matrix、固定 source、生成测试、迁移指南和中英文文档。CI 会校验这些关系、differential
report 与发布 archive。
