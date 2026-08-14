# Unicode MF2 语法与 interchange data model

[English](mf2-syntax-data-model.mbt.md)

`0.5.0` 新增独立 profile `unicode-mf2-ldml48.2-syntax-v1`，固定到 Unicode
MessageFormat WG commit `d115a614079678850aac8b52742360e888b8f027`。它面向工具、
编辑器、转换器和未来的标准模式 authoring，与生成应用当前使用的 strict-v1 catalog
formatter 相互隔离。

## 概念

- **Well-formedness** 表示源码符合固定版本的完整 grammar，但不代表 declaration
  data flow 或 selector variant 一定有效。
- **Validity** 是额外的 data-model 规则，包括 declaration binding、selector
  annotation、key 数量、fallback variant 与 NFC 等价重复检测。
- **Interchange data model** 是规范定义的逻辑消息树。它去掉 literal 是否使用引号等
  只属于源码的选择，使消息可以在 parser、翻译工具与转换器之间传递。
- **Cooked literal** 已经处理语法转义；重新序列化时可能采用不同但功能等价的 quoted
  form。
- **NFC equivalence** 表示 canonical-equivalent 的 Unicode 名称视为同一名称。解析后
  名称按 Unicode 16 数据规范化，literal 文本保持原值。
- Markup 是结构化数据，不是 HTML。MF2 模型允许没有配对的 open 或 close markup；
  renderer 必须自行定义安全消费方式。

## API 流程

编辑器需要在消息 invalid 时仍获得语法树，可调用 `parse_mf2_syntax`；interchange
或构建边界应调用 `parse_valid_mf2_model`。

~~~moonbit
let source =
  ".input {$count :number}\n.match $count\none {{One}}\n* {{Other}}"

match @i18n.parse_valid_mf2_model(source) {
  Ok(model) => {
    let canonical_syntax = @i18n.serialize_mf2_model(model)
    let interchange_json = @i18n.mf2_model_to_json(model)
    // 保存或转换任一确定性表示。
    ignore(canonical_syntax)
    ignore(interchange_json)
  }
  Err(errors) =>
    for error in errors {
      println(error.to_string())
    }
}
~~~

公共模型包括 `Mf2MessageModel`、declaration、pattern、expression、literal/variable
value、function、option、attribute、markup、selector 与 variant。源码 offset 是
Lampclaw 扩展，不会写入规范 JSON。

`serialize_mf2_model` 输出确定且功能等价的语法。pattern message 使用 quoted pattern，
避免开头内容被误认为 complex-message keyword；option 与 attribute 采用确定顺序。
serializer 会先验证公共模型，非法值不会产生部分输出。

`mf2_model_to_json` 与 `parse_mf2_model_json` 使用规范 JSON 字段名。按照 model
extension 规则，未知 object 字段会被忽略；非法 shape、名称、declaration 关系与
selector model 会被拒绝。相同逻辑模型总是得到以一个换行结尾的稳定 JSON。

## 错误模型

`Mf2Error.kind` 表示大类，`Mf2Error.code` 提供稳定、机器可读的具体原因。`0.5.0`
区分 syntax error，以及固定规范中的 variant-key mismatch、missing fallback variant、
missing selector annotation、duplicate declaration、duplicate option name 和 duplicate
variant；资源超限也有独立 code。

这些只是 parser 与 validity 错误。unresolved variable、unknown function、bad
operand/option/key、formatting failure 和 best-effort fallback 行为会在 `0.6.x`、
`0.7.x` 真正生效。

## 来源与限制

仓库在 Unicode 许可证下 vendored 精确的上游 `syntax.json`、`syntax-errors.json` 与
`data-model-errors.json`。生成的 MoonBit 测试覆盖全部 114 个接受语法用例、133 个
拒绝语法用例和 23 个 data-model 用例。同步及生成脚本校验固定 commit 与 SHA-256；
CI 会拒绝过期的生成测试。

parser 的限制为每条消息 64 KiB、4,096 个 declaration、64 个 selector、4,096 个
variant、每个 pattern model 65,536 个 part，以及每个 expression 或 markup 64 个
option。interchange JSON 同样有大小和嵌套深度限制。这些实现限制不改变限额以内所
支持的 grammar production。

## `0.5.0` 的刻意边界

本 API 不执行 declaration resolution、variant selection、value formatting、bidi
isolation 或 function registry，也不会改变现有 locale JSON 或 catalog-v2 的含义。
在 `0.8.x` 引入显式标准模式 authoring profile 前，应用仍应使用自身的 generated
facade。
