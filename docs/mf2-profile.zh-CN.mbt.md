# MessageFormat profile

[English](mf2-profile.mbt.md)

`0.5.0` 刻意提供两个彼此独立的 profile：

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` 是现有 catalog、generator、
  generated facade 与格式化流程使用的 profile。
- `unicode-mf2-ldml48.2-syntax-v1` 是新增的独立 Unicode MF2 语法与 interchange
  data model profile。它解析、校验固定版本的完整 grammar，但暂不格式化该模型。

这种隔离避免语法扩展悄悄改变已有 catalog 的含义。`0.5.0` 中常规 JSON authoring
和生成应用仍使用 strict-v1；catalog 的显式 `messageProfile` 选择在 `0.8.x` 引入。
独立 API 见[语法与数据模型指南](mf2-syntax-data-model.zh-CN.mbt.md)。

上游比较基线固定为 Unicode MessageFormat WG 的
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027)，
日期为 2026-06-11，属于 LDML 48.2 时期。不可变 pin、vendored fixture、Unicode
许可证与机器可读矩阵位于 `tests/unicode-mf2/`。

## 兼容矩阵

| 领域 | 现有 catalog profile | `unicode-mf2-ldml48.2-syntax-v1` |
|---|---|---|
| Grammar | 严格、按行的项目子集 | 固定版本的完整 message ABNF，包括 compact complex message |
| Well-formed 与 valid | compile/install 失败 | `parse_mf2_syntax` 与 `validate_mf2_model` 两个独立阶段 |
| Declaration 与选择 | 可直接运行的 strict-v1 模型 | 规范 declaration、selector、variant 与 data-model validity |
| Expression | runtime 支持的 operand 与 function | literal、variable、function-only、option 与 attribute |
| Markup | structured parts 中要求配对 | 规范的 open、close、standalone，以及刻意不配对的模型 |
| NFC 处理 | 不提供完整的 identifier/key NFC 规范化 | Unicode 16 NFC 名称及 NFC 等价重复检测 |
| Interchange model | 内部编译模型与 catalog JSON | 规范公共模型及确定性 JSON interchange |
| Formatting | 文本与 rich-parts 格式化 | 延后到 `0.6.x`、`0.7.x` |
| Function | `:string`、`:number`、`:integer`、`:offset`、私有 `:lampclaw:datetime` | 保留 function reference，不解释 registry 语义 |
| 错误 | 严格失败 | 固定语法错误及具体 data-model code；恢复行为尚未实现 |
| 方向性 | catalog direction metadata | grammar 接受 bidi control；输出 isolation 尚未实现 |

## Conformance 声明

`0.5.0` 只声明固定版本的 MF2 语法与 validity/data model 能力，不声明完整 Unicode
MessageFormat conformance。vendored 上游套件在四种 MoonBit backend 上验证 114 个
well-formed 语法用例、133 个 syntax-error 用例和 23 个 data-model 用例。resolution、
fallback formatting、bidi isolation、默认 function registry 与完整 formatting fixture
仍是后续版本门槛。

## 变更纪律

两个标识都是公开兼容契约。legacy catalog 标识参与每个 catalog contract hash。
任何语义扩展或不兼容收紧都必须变更对应标识，并在同一变更中同步矩阵、fixture、
测试及中英文文档。CI 会依据不可变上游 pin 校验这些来源。
