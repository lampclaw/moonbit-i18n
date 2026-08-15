# MessageFormat profile

[English](mf2-profile.mbt.md)

`0.9.0` 以 LDML 48.2 正式发布的 Unicode MessageFormat 2.0 文本为基线，冻结
JavaScript conformance candidate。Authoring 必须显式选择以下 message profile 之一：

- `unicode-mf2-ldml48.2-js-v2` 是推荐的稳定 profile，包含稳定的 `:string`、
  `:number`、`:integer`、`:offset`、`:currency`、`:percent`，并拒绝 Draft
  date/time function；
- `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` 在独立版本化、非稳定的
  契约下增加固定版本的 Draft `:date`、`:time` 与 `:datetime`；
- `unicode-mf2-ldml48.2-js-v1` 是 `0.8.x` standards profile，保留用于迁移，使用时
  输出 warning `I18N1004`；
- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` 是原始 compatibility profile，
  保留私有 `:lampclaw:datetime` 契约。

在 `0.9.0` 中，省略 `messageProfile` 是 error `I18N1003`。独立的 `pseudo`、XLIFF、
i18next 与 ARB 命令也必须传入 `--message-profile`。详见
[迁移指南](message-profile-migration.zh-CN.mbt.md)。

公开的 standalone standards core 继续保留三个更窄的 identifier：

- `unicode-mf2-ldml48.2-syntax-v1`：完整固定 grammar 与规范 interchange data model；
- `unicode-mf2-ldml48.2-resolution-v1`：resolution、selection、fallback、structured
  output、bidi isolation 与严格 BCP 47；
- `unicode-mf2-ldml48.2-default-functions-v1`：稳定默认 registry 与公开
  custom-function 边界。

## 固定的标准基线

规范来源是 Unicode MessageFormat WG 的正式 tag
[`LDML48.2`](https://github.com/unicode-org/message-format-wg/tree/LDML48.2)，commit
`7f142fb4f1f5ea6ab1eb34ce2b87e918ca9fd331`。完整不可变 source、hash、生成
fixture 与 Unicode license 位于 `tests/unicode-mf2/`。

`tests/unicode-mf2/standards.json` 还固定 CLDR 48.2、CLDR JSON 48.2.0、日期为
2026-08-08 的 IANA Language Subtag Registry，以及 Node 26.7.0 `Intl` host policy。
任何规范输入升级都必须显式审查 profile；CI 会拒绝移动引用或 hash 漂移。

## 兼容矩阵

| 领域 | 稳定 v2 | 实验 datetime | Legacy/compatibility |
|---|---|---|---|
| Authoring | 显式 `unicode-mf2-ldml48.2-js-v2` | 显式 `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` | 显式 v1 或 compatibility identifier |
| Grammar/model | 完整固定 MF2 grammar 与 valid model | 相同 | v1 使用相同 standards core；compatibility 使用严格项目子集 |
| Resolution/bidi | 规范 source order、selection、fallback、error 与 Unicode isolation | 相同 | v1 保留旧聚合语义；compatibility 保留 eager strict-v1 行为 |
| Function | 六个稳定 function | 稳定六项加三个固定 Draft date/time function | v1 接受 stable 与 Draft date/time；compatibility 增加私有 datetime |
| Catalog | catalog v2 加 profile 专属 contract hash | 相同 | 同样按 identity 明确失败 |
| Runtime 声明 | Node 26 JavaScript 与受支持浏览器 | 已测试但不计入稳定声明 | 仅用于迁移兼容 |

生成应用 authoring 不允许任意 custom function。底层用户可通过
`Mf2FunctionRegistry` 注册带 namespace 的 function，但扩展不计入 Unicode
conformance 声明。

## Conformance 声明

`0.9.0` JavaScript backend 是固定 stable MF2 范围的 release candidate，证据包括：

- 270 个上游 syntax/data-model case（114 well-formed、133 syntax error、23
  data-model）；
- Native、JavaScript、Wasm、Wasm-GC 上的 67 个 resolution、selection、fallback、
  bidi 与 Unicode-option case；
- 104 个 stable default-function case，加 20 个单独分类的 experimental date/time
  case；
- 77 条与规范 anchor 一一对应的 requirement、全部 6 个 stable function 和 40 个
  stable option，无法解释的 gap 与 blocker 均为零；
- 相对独立 `messageformat@4.0.0` 的 24 个 differential case，其中 20 个 stable、
  4 个 experimental date/time，无法解释的 semantic failure 为零；
- 在真实 Chromium、Firefox、WebKit 中运行相同 syntax、resolution、function 与
  differential suite，并验证六个 Rabbita 应用场景。

记录的 Node host 是 26.7.0，包含 ICU 78.3、CLDR 48.0、Unicode 17.0、tz 2026c。
浏览器测试会记录自己的 `Intl` fingerprint，使 host data 差异可见，不会被误判为 engine
bug。

声明刻意限制在稳定 JavaScript profile。Draft date/time 属于 experimental，Draft
`:unit` 暂缓，custom function 属于扩展，Native/Wasm 尚未携带项目自有 CLDR formatter。
因此 `0.9.0` 不声明在所有 backend 上覆盖每个 optional 或 Draft MF2 功能。

## 契约纪律

Profile identifier、catalog v2、diagnostics v1、manifest format、CLI surface、生成 facade
template 与公开 MoonBit interface 冻结在 `docs/contracts/1.0-candidate.json`。语义扩展或
不兼容收紧必须引入显式 profile/contract 迁移，并在同一变更中更新规范矩阵、fixture、
differential 证据、浏览器证据与中英文文档。
