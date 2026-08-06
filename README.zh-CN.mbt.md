# lampclaw/i18n

[English](README.mbt.md)

面向 MoonBit 的 typed 国际化：locale 协商、带版本的 catalog、实用的
MessageFormat 2 子集、JavaScript `Intl` 格式化、typed enum 生成、覆盖率检查、
pseudo locale 和 XLIFF 2.1 交换。

`0.1.0` 将 UI 框架和应用数据留在 core 之外。浏览器示例使用 Rabbita，但
`lampclaw/i18n` 本身也适用于命令行、服务端、测试和其他 UI package。

## 安装

模块发布之前，将本仓库与应用放进同一个 Moon workspace：

~~~toml
// moon.work
members = [
  "./moonbit-i18n",
  "./my-app",
]
~~~

~~~toml
// my-app/moon.mod
import {
  "lampclaw/i18n@0.1.0",
}
~~~

在使用它的 package 中导入运行时；JavaScript target 再导入 `Intl` formatter：

~~~toml
// my-app/main/moon.pkg
import {
  "lampclaw/i18n" @runtime,
  "lampclaw/i18n/js" @runtime_js,
}
~~~

发布后可用 `moon add lampclaw/i18n` 替代本地 workspace checkout。

## 推荐的 typed 工作流

应用拥有三类输入。本仓库不内置任何应用专属 locale 或消息名称。

~~~text
i18n/
  config.json
  schema.json
  locales/
    en-US.json
    zh-CN.json
~~~

`config.json` 声明 locale 策略和发布覆盖率下限：

~~~json
{
  "sourceLocale": "en-US",
  "defaultLocale": "zh-CN",
  "fallbackLocale": "en-US",
  "embeddedLocales": ["en-US", "zh-CN"],
  "release": { "minimumCoverage": 1.0 },
  "locales": {
    "en-US": { "direction": "ltr" },
    "zh-CN": { "direction": "ltr" }
  }
}
~~~

`schema.json` 是消息 ID 与参数类型的单一事实来源：

~~~json
{
  "messages": {
    "common": ["save"],
    "counter": ["count"]
  },
  "params": {
    "counter.count": [{ "name": "count", "type": "Int" }]
  },
  "descriptions": {
    "counter.count": "Visible click count"
  }
}
~~~

Locale 文件只保存翻译：

~~~json
{
  "common": { "save": "保存" },
  "counter": {
    "count": "已点击 {$count :number} 次"
  }
}
~~~

Locale 目录中的每个 `*.json` 都必须在 `config.json` 中声明；缺失、规范化后
重复或未声明的 locale 会提前失败。

使用显式路径生成 typed bindings 和带版本的 catalog：

~~~bash
moon run cmd/i18n -- generate \
  i18n/config.json \
  i18n/schema.json \
  i18n/locales \
  src/i18n/generated.mbt \
  public/i18n
~~~

生成的 MoonBit 文件提供 `Locale`、`I18nText`、每个消息分组的 enum、参数
转换、schema hash 和配置为内嵌的 catalog。Hash 由排序后的消息 ID 与参数
类型生成，因此 JSON 格式或 translator description 的修改不会让仍兼容的
catalog 失效。应用适配层可以据此暴露所需的 `t.t(...)` API：

~~~moonbit nocheck
let i18n = I18n::new()
let t = i18n.translator(ZhCN)

t.t(Common(Save))
t.t(Counter(Count(2)))
~~~

完整的 schema 到浏览器集成参见生成式
[Rabbita Todo 示例](examples/rabbita_todo/README.zh-CN.mbt.md)。

## MessageFormat 2 子集

消息支持 typed 变量和 formatter 标注：

~~~text
你好，{$name}
总计：{$total :number}
发布于：{$date :datetime year=|numeric| month=|long|}
~~~

Schema 参数类型支持 `String`、`Int`、`Double`、`Bool` 和 `DateTime`；生成的
`DateTime` 参数使用 ISO 日期时间 `String`。formatter 支持 `:number`、
`:integer` 和 `:datetime`。在 JavaScript 上，将
`@runtime_js.formatter()` 传给运行时即可使用平台的 `Intl` 数字、日期时间和
复数规则。其他 target 可以使用 `Formatter::basic()`，或提供相同的三个
formatter callback。

声明和 selector 可以表达常见复数与选择消息：

~~~text
.input {$count :number}
.match $count
one {{One item}}
* {{{$count} items}}
~~~

`.input`、`.local`、`.match`、精确数字 key、复数类别和 wildcard fallback
都会在生成 catalog 前校验。无效变量或未知变量会直接让生成失败，而不是留到
运行时才暴露。

Rich message 返回结构化 part，不要求应用注入 markup 字符串：

~~~moonbit nocheck
@runtime.format_mf2_rich(
  "阅读 {#link href=|/guide|}使用指南{/link}",
  "zh-CN",
  [],
  @runtime_js.formatter(),
)
~~~

结果包含 `RichText`、`RichOpen`、`RichClose` 和 `RichStandalone`。渲染前，
用应用的标签 allow-list 调用 `validate_rich_tags`。`0.1.0` 尚不支持 rich
selector message。

## 运行时与 catalog

不需要生成 bindings 时，也可以直接使用底层运行时：

~~~moonbit nocheck
let runtime = @runtime.I18n::new(
  fallback_locale_code="en-US",
  schema_hash="app-schema-v1",
  formatter=@runtime_js.formatter(),
)

runtime.install_catalog(
  @runtime.Catalog::new(
    locale_code="en-US",
    schema_hash="app-schema-v1",
    entries=[
      { id: "common.hello", message: "Hello {$name}" },
    ],
  ),
)

let t = runtime.translator("en-US")
let result = t.translate("common.hello", [
  { name: "name", value: @runtime.TextValue("MoonBit") },
])
~~~

Catalog JSON 包含 `catalogVersion`、`schemaHash`、规范化后的 `locale`、文字
方向和消息。`install_catalog_source_for` 会解析动态加载的 catalog，并在安装前
同时校验 locale 与 schema hash。

Locale 查找先搜索请求 locale 及其父级，再搜索配置的 fallback 链。例如
`zh-Hans-CN` 会依次查找 `zh-Hans-CN`、`zh-Hans` 和 `zh`。
`translator_from_code` 会先与已安装 catalog 协商。

`take_diagnostics()` 返回并清空结构化事件：

- `MessageFallback(requested, resolved, id)`
- `MissingMessage(locale, id)`
- `MessageFormatFailed(locale, id, reason)`

由应用决定记录、聚合还是展示这些事件。

## CLI

所有命令都要求显式输入和输出路径，不包含应用专属的默认目录。

~~~text
generate [--allow-partial] <config> <schema> <locale-dir> <output.mbt> <catalog-dir>
check    [--allow-partial] <config> <schema> <locale-dir> <output.mbt> <catalog-dir>
coverage                   <config> <schema> <locale-dir>
pseudo   <schema> <source-locale> <source.json> <en-XA|ar-XB> <output.json>
export-xliff <schema> <source-locale> <source.json> <target-locale> <target.json|-> <output.xlf>
import-xliff <schema> <target-locale> <input.xlf> <output.json>
~~~

- `generate` 写入格式化后的 bindings，以及每个已配置 locale 的 catalog。
- `check` 在内存中执行相同生成，并在 catalog 产物改变、缺失或意外多出时失败。
- `coverage` 报告已翻译/总消息数，不强制发布下限。
- 开发阶段可用 `--allow-partial` 关闭发布覆盖率下限；source 与 fallback
  locale 仍必须完整。
- `pseudo` 生成带重音的 `en-XA` 或 RTL 包裹的 `ar-XB`，同时保留 MF2
  expression 与 selector 语法。
- XLIFF 2.1 导入导出会保留消息 ID、description 和 MF2 文本。

## 示例

- [Basic](examples/basic) 展示字符串 ID 查找与 fallback。
- [Typed](examples/typed) 展示最小的手写 enum 适配层。
- [Rabbita Counter](examples/rabbita_web/README.zh-CN.mbt.md) 是小型手写 typed
  浏览器集成。
- [Rabbita Todo](examples/rabbita_todo/README.zh-CN.mbt.md) 使用生成 enum、
  catalog、参数、覆盖率检查和完整 `t.t(...)` 工作流。

两个 Rabbita 示例都是独立 workspace module，因此 Rabbita 不是 core library
的依赖。

## 验证仓库

~~~bash
moon info
moon fmt --check
moon check --target js
moon test --target native
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon build --target js

moon run cmd/i18n -- check \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales \
  examples/rabbita_todo/main/generated.mbt \
  examples/rabbita_todo/public/i18n
~~~

浏览器 release 构建：

~~~bash
cd examples/rabbita_web
warren build --dist /tmp/moonbit-i18n-rabbita-counter

cd ../rabbita_todo
warren build --dist /tmp/moonbit-i18n-rabbita-todo
~~~

## 架构

~~~text
config + schema + locale JSON
             │
             ▼
      generator / CLI ──────── coverage、pseudo、XLIFF
          │       │
          ▼       ▼
  typed bindings  catalog JSON
          │       │
          └───┬───┘
              ▼
       I18n + Translator
              │
       MF2 + Formatter
              │
              ▼
       应用 / UI 适配层
~~~

仓库不包含应用业务资源、应用 loader 或旧版 generator 入口；实现是通用模块，
示例基于上游 Rabbita examples。

## 许可证

Apache-2.0，参见 [LICENSE](LICENSE)。
