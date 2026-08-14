# MF2 默认函数与 registry

[English](mf2-default-functions.mbt.md)

`0.7.0` 在 syntax 与 resolution profile 之上增加固定 registry profile
`unicode-mf2-ldml48.2-default-functions-v1`。其参考点是 LDML 48.2 时期的
Unicode MessageFormat WG commit
`d115a614079678850aac8b52742360e888b8f027`。

## 支持范围

| 固定规范中的状态 | Function | `0.7.0` 状态 |
|---|---|---|
| Stable 且 required | `:string`、`:number`、`:integer`、`:offset`、`:currency`、`:percent` | 已实现 required operand、option、继承、formatting 与 selection |
| Draft | `:date`、`:time`、`:datetime` | 因路线图要求而实现，但不计入 stable conformance 声明 |
| Draft 且 recommended | `:unit` | 暂缓，解析为 unknown function |

JavaScript provider 使用 Node 26 的 `Intl.NumberFormat`、`Intl.PluralRules`
与 `Intl.DateTimeFormat`，并把宿主 `formatToParts()` 字段保存在
`Mf2FormattedExpression.fields`。对 currency display `never`、语义化 date/time
field、floating ISO date/time、固定 offset 和 context time zone，在直接 `Intl`
option 不足时提供边界明确的兼容处理。

Native、Wasm 与 Wasm-GC 使用 `Formatter::basic()`。该可移植 provider 支持 string、
普通十进制 number、integer 与 offset；需要 locale 或 CLDR 数据的操作返回
`Mf2UnsupportedOperationCode`，不会静默近似。这些 backend 不计入 JavaScript 默认函数
conformance 声明。

## JavaScript 使用方式

完整平台 registry 位于 `runtime/js`：

~~~moonbit
let context = match @runtime.Mf2FormattingContext::new(
  locale="zh-CN",
  inputs=[
    @runtime.Mf2Input::new("price", @runtime.DoubleValue(42.0)),
    @runtime.Mf2Input::new("count", @runtime.IntValue(2)),
  ],
  time_zone="Asia/Shanghai",
  bidi_isolation=@runtime.Mf2NoBidiIsolation,
) {
  Ok(value) => value
  Err(error) => abort(error.to_string())
}

let result = @runtime_js.format_mf2(
  ".input {$count :integer}\n{{{$price :currency currency=CNY} / {$count}}}",
  context,
)

println(result.value)
for error in result.errors {
  println(error.to_string())
}
~~~

应用需要注册 custom function 时，先取得 `@runtime_js.mf2_registry()`，再调用
`@runtime.format_mf2`。`format_mf2_standalone` 使用 portable 默认 registry，因此不提供
CLDR 输出。

Numeric resolved value 会保留适用的语义 option；后续 `:number`、`:integer`、
`:offset`、`:currency` 或 `:percent` expression 按固定规范执行继承和丢弃规则。
Numeric selector 先匹配 exact key，再匹配 CLDR cardinal/ordinal category。非 literal
`select` 是 non-fatal bad option：formatting 继续可用，selection 按规范禁用。

Date/time input 可以是 `InstantMillis` 或严格 ISO date/time string。
`Mf2FormattingContext.time_zone()` 是默认时区，默认值为 `UTC`。三个 date/time function
遵循固定 draft semantic-skeleton option；Unicode 若以不同范围将其稳定，其 API 或输出
契约仍可能调整。

## 可移植 custom function

Custom identifier 必须带 namespace，不能使用保留的 `u` namespace，也不能在 NFC
normalization 后冲突。Registry 向 handler 提供 typed raw operand、lazy formatting、继承
metadata、已解析 option，以及 locale/direction context，并允许提供 selection callback：

~~~moonbit
let registry = @runtime_js.mf2_registry()
let echo = @runtime.Mf2FunctionHandler::new(
  name="app:echo",
  resolve=(_context, operand, _options) => {
    guard operand is Some(operand) else {
      return Err(@runtime.Mf2FunctionBadOperand("missing operand"))
    }
    Ok(
      @runtime.Mf2FunctionValue::new(
        raw=operand.raw(),
        direction=operand.direction(),
        format=() => operand.format(),
      ),
    )
  },
)

match registry.register_custom(echo) {
  Ok(_) => ()
  Err(message) => abort(message)
}

let result = @runtime.format_mf2(
  "{hello :app:echo}",
  context,
  registry,
)
~~~

Custom function 属于应用行为，始终排除在 Unicode conformance 声明之外。Handler 使用
typed `Mf2FunctionFailure` 报错，也可随可用 value 返回 non-fatal issue。

## 证据与边界

Node 26 JavaScript provider 通过全部 124 个 vendored 上游 function case：12 个
currency、7 个 draft date、7 个 draft datetime、13 个 integer、41 个 number、16 个
offset、13 个 percent、9 个 string 与 6 个 draft time。CI 校验精确 source、hash、
function 规范正文、生成测试与数量。

这仍不是完整 Unicode MF2 声明。Catalog authoring profile 选择、从
`:lampclaw:datetime` 迁移、requirement-to-test 规范矩阵与独立 differential conformance
属于 `0.8.x` 的收口工作。
