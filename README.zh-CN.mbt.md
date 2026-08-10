# lampclaw/i18n

[English](README.mbt.md)

`lampclaw/i18n` 是 MoonBit 的类型安全、生成优先 i18n 工作流。版本仍停留在
尚未发布的 `0.1.0` 开发阶段。当前面向应用的 facade 以 JavaScript 为首要目标，
并自动使用平台的 `Intl` 实现。

应用开发者通过 JSON 资源编写消息，生成独立的 MoonBit package，再翻译类型化的
消息值；无需手工构造 catalog、消息参数或 formatter。

## Authoring 模型

典型应用把可编辑的本地化输入与生成 package 分开：

~~~text
app/
├── localization/
│   ├── config.json
│   ├── schema.json
│   └── locales/
│       ├── en-US.json
│       └── zh-CN.json
├── i18n/                 # 完全由生成器管理
│   ├── generated.mbt
│   └── moon.pkg
└── main/
    ├── main.mbt
    └── moon.pkg
~~~

`localization/schema.json` 定义类型化消息契约：

~~~json
{
  "messages": {
    "common": ["hello"],
    "cart": ["item_count"]
  },
  "params": {
    "common.hello": [{ "name": "name", "type": "String" }],
    "cart.item_count": [{ "name": "count", "type": "Int" }]
  }
}
~~~

每个 locale 提供消息文本，也可以使用 MF2 表达式和 matcher：

~~~json
{
  "common": {
    "hello": "你好 {$name}"
  },
  "cart": {
    "item_count": "{$count :number} 件商品"
  }
}
~~~

`localization/config.json` 声明 locale 行为和发布覆盖率：

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

## 生成与校验

在模块 workspace 中执行：

~~~bash
moon run cmd/i18n -- generate \
  app/localization/config.json \
  app/localization/schema.json \
  app/localization/locales \
  app/i18n \
  app/public/i18n

moon run cmd/i18n -- check \
  app/localization/config.json \
  app/localization/schema.json \
  app/localization/locales \
  app/i18n \
  app/public/i18n
~~~

第四个参数是输出 package 目录，而不是单个源码文件。生成器拥有
`generated.mbt` 和 `moon.pkg`：两个文件都带所有权标记；生成器拒绝覆盖没有标记
的文件，也拒绝 package 内出现额外 `.mbt` 文件。`check` 只读，会检测源码、
manifest、catalog 以及文件集合漂移。

迭代期间，非 source locale 未达到覆盖率时可使用 `--allow-partial`。source 和
fallback locale 始终必须完整。空字符串或只有空白的值会被视为缺失翻译。

## 应用依赖与使用

本地开发时，可把库模块和应用模块放进同一个 workspace：

~~~text
members = [
  ".",
  "app",
]
~~~

应用模块声明 `0.1.0` 依赖：

~~~text
import {
  "lampclaw/i18n@0.1.0",
}
~~~

业务 package 只导入自身生成的 package：

~~~text
import {
  "acme/todo/i18n" @app_i18n,
}
~~~

翻译调用全程类型安全：

~~~moonbit
let i18n = @app_i18n.I18n::new()
let t = i18n.default_translator()

let greeting = t.t(
  @app_i18n.Common(@app_i18n.Hello("MoonBit")),
)
let count = t.t(
  @app_i18n.Cart(@app_i18n.ItemCount(3)),
)
~~~

生成的 facade 提供：

- `I18n::new()`，自动安装内嵌 catalog 并使用 JavaScript `Intl`；
- `default_translator()`、`translator(Locale)`、`translator_from_code(String)`
  和 `translator_from_codes(Array[String])`；
- `resolve_locale_codes(Array[String])`，用于在不构造 translator 的情况下按顺序
  协商 locale；
- 类型化的 `Translator::t(I18nText)`；
- 用于动态 catalog 的 `install_catalog_source(Locale, String)`；
- `has_catalog(Locale)` 与 `installed_locales()`；
- 通过 `take_diagnostics()` 获取应用层诊断。

locale code 会处理常见的大小写与下划线差异。不支持的请求 locale 会协商到配置的
default locale；具体消息缺失时仍按 fallback locale 查找。

## Catalog 是部署产物

Catalog JSON 适合懒加载、CDN 分发、schema 兼容检查、locale 元数据和诊断，但它
不是第二套用户 authoring API。作者只编辑 locale 资源，由生成器产出带版本的
catalog。需要懒加载时，应用把下载的 JSON 交给生成 facade 的
`install_catalog_source`。

catalog format version `1` 包含 `catalogVersion`、`schemaHash`、`locale`、
`direction` 和扁平的 `messages`。安装时会拒绝不支持的版本、过期 schema hash
和 locale 不匹配。

## 校验与工具

生成阶段会校验所有 MF2 matcher 分支、selector 值类型、variant key 数量、重复
声明/selector/variant key，以及必需的全通配 fallback。同时会校验生成标识符冲突、
locale 归一化冲突、source/fallback 完整性和发布覆盖率。

工具还支持覆盖率报告、`en-XA`/`ar-XB` 伪本地化和 XLIFF 2.1 导入导出。完整命令
可运行 `moon run cmd/i18n` 查看。

## 示例

[`examples/rabbita_todo`](examples/rabbita_todo/README.zh-CN.mbt.md) 展示浏览器应用的
完整 package 生成工作流；其维护源码只导入自己的生成 i18n package。

底层集成 API 已与普通 authoring 分离。生成器或框架维护者可阅读
[`docs/runtime-spi.zh-CN.mbt.md`](docs/runtime-spi.zh-CN.mbt.md)。

## 当前范围

生成的应用 facade 当前以 JS 为首要目标。类型化 rich-message authoring、
Native/Wasm 完整 CLDR、完整 BCP 47、catalog AST 预编译、更强契约 hash，以及基于
真实 XML parser 的 XLIFF 支持留待后续版本。

## 许可证

Apache-2.0
