# MF2 resolution 与 formatting core

[English](mf2-resolution-formatting.mbt.md)

`0.6.0` 新增独立 profile `unicode-mf2-ldml48.2-resolution-v1`。它构建在固定版本的
syntax 与 interchange model 上，但不改变已有 catalog profile 和 canonical JSON
authoring 工作流。

本阶段实现 parser 与默认 function registry 之间、与目标平台无关的语义：

- declaration 按源码顺序解析，每个 expression 最多求值一次；
- literal、variable、option、`u:id` 与 `u:dir` 遵循固定规范的 resolution 规则；
- 多 selector variant 使用规范的 Match/BetterThan 比较算法和 NFC key；
- syntax、data-model、resolution 与 message-function error 保持可发现，同时 valid
  message 仍产生 best-effort 输出；
- expression 与整条 message fallback 使用规范的可打印表示；
- plain-text 输出默认使用 Unicode bidi isolation，除非调用方显式关闭；
- structured output 将 markup、attribute、已解析 option、ID、方向和 isolation control
  保留为惰性数据。

稳定默认 function registry 与公开 custom-function registry 属于 `0.7.x`。因此
`0.6.0` 的 `format_mf2_standalone` 会把带 annotation 的 function 报告为
`unknown-function`；这是明确边界，不是近似实现。内部 conformance provider 只供测试，
不是用户扩展点。

## 基本用法

先创建严格 context，再格式化 source 或已解析 model：

~~~moonbit
let context = match @runtime.Mf2FormattingContext::new(
  locale="zh-CN",
  inputs=[
    @runtime.Mf2Input::new(
      "name",
      @runtime.TextValue("MoonBit"),
      direction=@runtime.Mf2LeftToRight,
    ),
  ],
  direction=@runtime.Mf2LeftToRight,
) {
  Ok(value) => value
  Err(error) => abort(error.to_string())
}

let result = @runtime.format_mf2_standalone("你好，{$name}！", context)
println(result.value)
for error in result.errors {
  println(error.to_string())
}
~~~

只有当 expression 明确为 LTR、整条 message 也是 LTR，且 `u:dir` 没要求 isolation
时，默认策略才不加控制符；其他情况使用 LRI、RLI 或 FSI，并以 PDI 结束。方向来自调用方
或 function provider 提供的 metadata，runtime 不扫描格式化文本猜测方向。只有在呈现层
提供等价 isolation 时，才应选择 `Mf2NoBidiIsolation`。

## Best-effort 结果契约

`Mf2FormatResult` 始终包含三个字段：

- `value` 是拼接后的 plain text，markup 对字符串贡献空串；
- `parts` 是不绑定 renderer 的 text、expression、markup 与 bidi-isolation 记录序列；
- `errors` 是本次操作按确定顺序发现的错误。

例如，缺失 `$name` 会输出 `{$name}` 并报告 `Mf2UnresolvedVariableCode`；带 literal
operand 的 function 失败会输出 `{|literal|}`。无效 message 输出 `{�}`，或将 context
中非空的 message fallback 放进大括号。Syntax 与 data-model error 的优先级高于运行期
error。

Markup 永远不会被执行。`Mf2FormattedMarkup` 只暴露 kind、identifier、已解析的惰性
option、source attribute 和可选 `u:id`。runtime 不生成 HTML、不调用 callback、不强制
平衡规范允许的非平衡 MF2 markup，也不提供 DOM renderer。应用必须通过自己的 allowlist
renderer 映射已知 markup identifier。

## BCP 47 与 lookup 边界

`canonicalize_locale_tag` 是严格入口。它依据固定到 `2026-08-08` 的 IANA Language
Subtag Registry，实现 RFC 5646 syntax 与 canonicalization：

- whole-tag 和 subtag Preferred-Value 映射；
- 已注册 extlang 替换和 prefix 校验；
- language/script/region 大小写规范化；
- 拒绝重复 variant 与 extension singleton；
- extension canonical 排序；
- 保留 private-use 数据。

严格入口拒绝 `_` separator。已有 `normalize_locale_code` 继续保留旧 catalog 所需的
宽松下划线/字母数字兼容面；新的标准模式代码不应依赖这项兼容行为。

`strict_locale_lookup_chain` 实现 RFC 4647 lookup 截断，包括将 singleton 与最近的尾随
subtag 一起移除。`negotiate_locale_code` 会 canonicalize 每个配置项，拒绝
canonicalization 后冲突的 supported tag，按顺序处理 requested range，跳过 `*`，并且
只在所有 request 失败后返回调用方持有的可选 default。它不会猜测语言之间的 fallback
关系。

registry 日期和 SHA-256 通过 `BCP47_REGISTRY_DATE` 与
`BCP47_REGISTRY_SHA256` 暴露。更新必须审核 registry diff，并通过
`scripts/sync-bcp47-registry.mjs` 重新生成；runtime 不依赖在线访问 IANA。

## Conformance 与限制

固定点仍为 Unicode MessageFormat WG commit
`d115a614079678850aac8b52742360e888b8f027`。除了 `0.5.0` 的 270 个 syntax/data-model
用例，固定上游的 67 个 fallback、pattern-selection、bidi 与 Unicode-option 用例也使用
测试套件指定的 conformance function，在 Native、JavaScript、Wasm 与 Wasm-GC 全部
通过。

这证明的是具名 resolution-core profile，而不是完整 Unicode MF2。默认 `:string`、
`:number`、`:integer`、`:date`、`:time`、`:datetime` 行为、宿主 CLDR 输出和公开
function registry 仍不属于 `0.6.0` 声明。

context 最多接受 64 个 input；source 与格式化输出分别限制为 64 KiB；原有 declaration、
selector、variant、option 与 pattern-part 限制继续生效。超过限制时会报告错误，并返回
有界的整条 message fallback，而不是部分、不安全的输出。
