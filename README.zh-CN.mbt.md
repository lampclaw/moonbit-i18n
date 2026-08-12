# lampclaw/i18n

[English](README.mbt.md)

`lampclaw/i18n` 是 MoonBit 的类型安全、生成优先 i18n 工作流。
`0.1.0-rc.2` 以一个模块发布 runtime、generator 与可移植 `moonx` CLI。生成的应用
facade 当前面向 JavaScript，并通过 `Result` 错误边界使用宿主环境的 `Intl`。

常规 authoring 界面是 JSON：编辑 schema 与 locale 资源，生成专用 MoonBit package，
业务代码只导入这个生成 package。catalog JSON 是用于内嵌或动态加载的生成部署产物，
不是第二种 authoring 格式。

## 路线图与当前状态

`0.1.0-rc.2` 是可供 Web/JavaScript 项目进行工程验证的 release candidate，不是
原型，也不表示完整通过 Unicode MessageFormat 2。公开的
[产品路线图](docs/roadmap.zh-CN.mbt.md) 以版本门槛定义从当前 Web profile，经
authoring 与交付完善，最终到 JavaScript 后端完整 MF2 的推进路径。
[当前 MF2 profile](docs/mf2-profile.zh-CN.mbt.md) 仍是已经发布能力的事实依据；
路线图中的规划项不代表当前已经支持。
精确的工具链、操作系统、浏览器、后端和 prerelease 兼容承诺见
[支持政策](docs/support-policy.zh-CN.mbt.md)。

## 安装与运行 CLI

向应用模块添加库依赖：

~~~bash
moon add lampclaw/i18n@0.1.0-rc.2
~~~

直接运行 registry 中固定版本的 CLI，无需全局安装：

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 --help
~~~

`moon add --bin lampclaw/i18n@0.1.0-rc.2` 是可选的项目级二进制依赖，并非
主流程。也可用
`moon install lampclaw/i18n/cmd/i18n@0.1.0-rc.2` 全局安装，命令名为
`moon-i18n`。

本项目刻意只发布一个模块。因此，即使应用只导入 runtime，`moon add` 也会解析 CLI
使用的精确 parser/async 依赖；只要可达的应用 package 没有导入它们，它们不会链接
进生成的 JavaScript 应用。

## Authoring 模型

~~~text
app/
├── localization/
│   ├── config.json
│   ├── schema.json
│   └── locales/
│       ├── en-US.json
│       └── zh-CN.json
├── i18n/                 # 完全生成的 MoonBit package
│   ├── generated.mbt
│   └── moon.pkg
└── main/
    ├── main.mbt
    └── moon.pkg
~~~

`localization/schema.json` 定义消息 ID 与参数类型：

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

参数类型支持 `String`、`Int`、`Double`、`Bool` 和 `InstantMillis`。列在
`parts` 下的消息会获得独立的类型安全 rich-parts API，并且只能使用声明的 MF2
markup 名称。

每个 locale 提供 MF2 源文本：

~~~json
{
  "common": { "hello": "你好 {$name}" },
  "cart": { "item_count": "{$count :number} 件商品" }
}
~~~

`localization/config.json` 控制 locale 协商、内嵌和发布覆盖率：

~~~json
{
  "sourceLocale": "en-US",
  "defaultLocale": "zh-CN",
  "fallbackLocale": "en-US",
  "embeddedLocales": ["en-US"],
  "release": { "minimumCoverage": 1.0 },
  "locales": {
    "en-US": { "direction": "ltr" },
    "zh-CN": { "direction": "ltr" }
  }
}
~~~

这个配置只内嵌英文；生成的 `zh-CN.json` 可以稍后下载并动态安装。

## 生成与校验

在应用模块中运行：

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 generate \
  localization/config.json \
  localization/schema.json \
  localization/locales \
  i18n \
  public/i18n

moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 check \
  localization/config.json \
  localization/schema.json \
  localization/locales \
  i18n \
  public/i18n
~~~

第四个参数是专用输出 package 目录，而不是单个源码文件。生成器校验所有权、锁定
两个绝对目标路径、暂存两个目标，再以可恢复事务一起切换；它拒绝 symlink 或非自身
内容，并删除过期 catalog。`check` 只读，会检测源码、manifest、catalog、所有权和
文件集合漂移。

生成的 package、catalog 和 `.lampclaw-i18n.json` 所有权 manifest 应提交到版本
控制。以 SHA-256 命名的持久 `*.lampclaw.lock` 在用户 cache 中分别协调每个绝对
目标，而不会落入任何输出目录；可用 `LAMPCLAW_I18N_STATE_DIR` 覆盖状态位置。生成
package 也会让 `moon fmt` 跳过 `generated.mbt`，因为它已经由固定版本的 CLI
formatter 规范化。

翻译期间，非 source locale 未达到覆盖率时可用 `--allow-partial`。source 与 fallback
locale 始终必须完整；空字符串或只有空白的消息视为未翻译。

## 应用使用

应用 package 只导入自身生成的 package：

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

动态部署某个 locale 时，获取其生成 catalog 文本，在创建或使用对应 translator 前安装：

~~~moonbit
match i18n.install_catalog_source(@app_i18n.ZhCN, downloaded_catalog_json) {
  Ok(_) => ()
  Err(message) => println("catalog rejected: \{message}")
}
let zh = i18n.translator(@app_i18n.ZhCN)
~~~

facade 还提供 locale 协商、严格的 `try_t`/`try_t_parts`、便捷的
`t`/`t_parts`、catalog 状态和有界去重诊断。动态安装会先检查 catalog 版本、
formatter profile、SHA-256 契约 hash、locale 身份、消息有效性与资源限制，再改变
runtime 状态。

## 工具与支持 profile

CLI 还提供 `coverage`、`pseudo`、`export-xliff` 和 `import-xliff`。XLIFF 2.1
导入会核验 source 内容及两端 locale，拒绝不安全 XML 和 MF2 字段内的 inline XML，
并保留转义文本、CDATA、实体和排版空白。

catalog profile 为 `lampclaw-mf2-strict-v1+lampclaw-datetime-v1`。它支持 MF2
pattern、declaration、matcher、markup parts、`:string`、`:number`、`:integer`、
`:offset`，以及针对 `InstantMillis` 的 `:lampclaw:datetime`。不支持的可选 registry
function 会被明确拒绝，而不是近似处理。这是严格的项目子集，不表示完整通过 Unicode
MessageFormat 2。精确能力矩阵和固定上游快照见
[`docs/mf2-profile.zh-CN.mbt.md`](docs/mf2-profile.zh-CN.mbt.md)。

完整 BCP 47 canonicalization 与 Unicode bidi isolation 不属于本次 RC。限制包括：
1,000 个 locale、64 MiB locale 总输入、64 MiB 生成 MoonBit、16 MiB/100,000 条消息
的 catalog、每条消息 64 KiB，以及每个生成消息 64 个参数或 rich tag。

## 示例与底层 API

源码仓库中的
[`examples/rabbita_todo`](https://github.com/lampclaw/moonbit-i18n/tree/v0.1.0-rc.2/examples/rabbita_todo)
演示完整浏览器流程。示例刻意排除在发布 archive 外，registry 页面专注于库本身。

框架与 generator 维护者可以使用有文档的 `runtime` 与 `generator` package；普通应用
应优先使用生成 facade。见
[`docs/runtime-spi.zh-CN.mbt.md`](docs/runtime-spi.zh-CN.mbt.md)。

## 许可证

Apache-2.0
