# MF2 默认函数与 registry

[English](mf2-default-functions.mbt.md)

`0.7.0` 增加、`0.8.0` 集成、`0.9.0` 冻结了 syntax 与 resolution profile 之上的
registry profile `unicode-mf2-ldml48.2-default-functions-v1`。其规范参考点是正式 tag
`LDML48.2`，commit `7f142fb4f1f5ea6ab1eb34ce2b87e918ca9fd331`。

## 支持范围

| 固定规范中的状态 | Function | 当前状态 |
|---|---|---|
| Stable 且 required | `:string`、`:number`、`:integer`、`:offset`、`:currency`、`:percent` | 已实现 required operand、option、继承、formatting 与 selection |
| Draft | `:date`、`:time`、`:datetime` | 只在 `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` 中实现；不属于 stable v2 |
| Draft 且 recommended | `:unit` | 暂缓，解析为 unknown function |

稳定生成 authoring 使用 `unicode-mf2-ldml48.2-js-v2`，会拒绝三个 Draft date/time
function。明确需要它们的应用必须选择独立版本化的 experimental datetime profile。

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

Numeric resolved value 会保留适用的语义 option，并继承 formatting context direction，
避免对同方向格式化值添加不必要的 isolation；后续 `:number`、`:integer`、
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

Node 26 JavaScript provider 通过全部 104 个 stable vendored function case：12 个
currency、13 个 integer、41 个 number、16 个 offset、13 个 percent 与 9 个 string。
Experimental profile 另行通过 20 个 Draft case：7 个 date、7 个 datetime、6 个 time。
CI 校验精确 source、hash、function 规范正文与数量，并在 Chromium、Firefox、WebKit
重复运行。

`0.9.0` 完成 conformance-candidate 集成：stable v2 不会意外 author Draft function；
私有 datetime 限制在 compatibility profile；77 行 anchored requirement matrix 覆盖全部
6 个 stable function 和 40 个 stable option；20 个 stable differential case 与 4 个
experimental date/time case 分开统计。Draft/custom function 与非 JavaScript CLDR 输出
仍不计入稳定声明。
