# lampclaw/i18n

[English](README.mbt.md)

`lampclaw/i18n` 是 MoonBit 的类型安全、生成优先 i18n 工作流。
`0.9.0` 以一个模块发布 runtime、generator、可移植 `moonx` CLI，以及独立的固定
Unicode MF2 语法/data-model、resolution、stable 默认函数与公开 registry API。生成的应用 facade 当前面向
JavaScript，并通过 `Result` 错误边界使用宿主环境的 `Intl`。

常规 authoring 界面是 JSON：编辑 schema 与 locale 资源，生成专用 MoonBit package，
业务代码只导入这个生成 package。catalog JSON 是用于内嵌或动态加载的生成部署产物，
不是第二种 authoring 格式。

## 路线图与当前状态

`0.9.0` 是路线图中 JavaScript 的 Unicode MF2 conformance candidate。新 scaffold 会
端到端使用显式 stable `unicode-mf2-ldml48.2-js-v2`。Draft `:date`、`:time`、
`:datetime` 必须使用单独命名的
`unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1`。省略 `messageProfile` 是 error
`I18N1003`；legacy standards v1 作为带 warning 的迁移桥梁保留。

本版本冻结正式 Unicode LDML 48.2 source、77 行 anchored normative matrix、独立
`messageformat@4.0.0` differential 证据，以及真实 Chromium、Firefox、WebKit
conformance run。公开 interface、生成 template、CLI 与 wire contract 已记录为 1.0
候选；但不会声明 Draft function 或每个 backend 都具备项目自有 CLDR formatting。公开的
[产品路线图](docs/roadmap.zh-CN.mbt.md) 以版本门槛定义从当前 Web profile，经
authoring 与交付完善，最终到 JavaScript 后端完整 MF2 的推进路径。
[当前 MF2 profile](docs/mf2-profile.zh-CN.mbt.md) 仍是已经发布能力的事实依据；
路线图中的规划项不代表当前已经支持。
精确的工具链、操作系统、浏览器、后端和 `0.x` 兼容承诺见
[支持政策](docs/support-policy.zh-CN.mbt.md)。

## 安装与运行 CLI

向应用模块添加库依赖：

~~~bash
moon add lampclaw/i18n@0.9.0
~~~

直接运行 registry 中固定版本的 CLI，无需全局安装：

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.9.0 --help
~~~

`moon add --bin lampclaw/i18n@0.9.0` 是可选的项目级二进制依赖，并非
主流程。也可用
`moon install lampclaw/i18n/cmd/i18n@0.9.0` 全局安装，命令名为
`moon-i18n`。

在尚不存在的路径中创建完整双语言 JavaScript 模块：

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.9.0 scaffold acme/hello ./hello
cd hello
moon update
moon run --target js main
~~~

scaffold 会拒绝任何已经存在的目标，包括非空或不归工具所有的目录。它先在目标旁边
暂存全部源文件和生成文件，再通过一次 rename 发布。

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
│   ├── generation-manifest.json
│   └── moon.pkg
├── public/i18n/          # 生成的 deployment manifest + namespace chunk
│   ├── manifest.json
│   ├── en-US--common.json
│   └── zh-CN--common.json
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
  "messageProfile": "unicode-mf2-ldml48.2-js-v2",
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

这个配置只内嵌英文；生成的 `zh-CN--common.json` namespace chunk 可以稍后下载，
根据 `manifest.json` 完成校验后独立安装。

## 生成与校验

在应用模块中运行：

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.9.0 generate \
  localization/config.json \
  localization/schema.json \
  localization/locales \
  i18n \
  public/i18n

moonx lampclaw/i18n/cmd/i18n@0.9.0 check \
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
当每个字节和预期文件都一致时，`generate` 不会创建 stage、journal 或替换目录，
而是真正的 no-op。

生成的 package、catalog 和 `.lampclaw-i18n.json` 所有权 manifest 应提交到版本
控制；`generation-manifest.json` 也应提交，它以版本化契约记录输入/输出相对路径、
字节数、SHA-256、message profile 和类型契约 hash。以 SHA-256 命名的持久
`*.lampclaw.lock` 在用户 cache 中分别协调每个绝对
目标，而不会落入任何输出目录；可用 `LAMPCLAW_I18N_STATE_DIR` 覆盖状态位置。生成
package 也会让 `moon fmt` 跳过 `generated.mbt`，因为它已经由固定版本的 CLI
formatter 规范化。

翻译期间，非 source locale 未达到覆盖率时可用 `--allow-partial`。source 与 fallback
locale 始终必须完整；空字符串或只有空白的消息视为未翻译。

在任意命令后追加 `--diagnostic-format=json` 可获得版本化的 CI/editor 格式；默认的
人类可读形式是 `path:line:column: error[CODE]: message`。两种形式都携带稳定 code、
源路径和半开 span。成功生成也可能输出 profile 迁移 warning；warning 不改变生成
字节或退出状态。详见[诊断契约](docs/diagnostics.zh-CN.mbt.md)。

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

动态部署某个 locale 时，从 deployment manifest 选择 locale/namespace 项，由应用校验
精确字节数和 SHA-256，再在使用对应路由前安装文本：

~~~moonbit
match i18n.install_catalog_chunk_source(
  @app_i18n.ZhCN,
  @app_i18n.CatalogCommon,
  verified_catalog_json,
) {
  Ok(_) => ()
  Err(message) => println("catalog rejected: \{message}")
}
let zh = i18n.translator(@app_i18n.ZhCN)
~~~

facade 还提供 locale 协商、严格的 `try_t`/`try_t_parts`、便捷的
`t`/`t_parts`、catalog 状态和有界去重诊断。动态安装会先检查 catalog 版本、
formatter profile、SHA-256 契约 hash、locale/namespace 身份、消息有效性与资源限制，
再改变 runtime 状态。网络、cache、integrity、retry 和 locale commit 策略仍由应用
持有；详见[生产级 Web 交付契约](docs/web-delivery.zh-CN.mbt.md)。

## 工具与支持 profile

CLI 还提供 `coverage`、`pseudo`、带状态的 `export-xliff`/`import-xliff`，以及单向
`import-i18next`/`import-arb` 迁移。这些独立命令不读取应用 config，因此应传入
`--message-profile unicode-mf2-ldml48.2-js-v2`；省略属于 CLI usage error。XLIFF 2.1
导入会核验 source 内容及两端
locale，拒绝不安全 XML 和 MF2 字段内的 inline XML，并返回版本化 lifecycle state
与 loss report。translator note、reviewed/final state、受支持 metadata、显式 ID
rename/removal 的完整契约见[翻译生命周期文档](docs/translation-lifecycle.zh-CN.mbt.md)。

新应用应显式选择 `unicode-mf2-ldml48.2-js-v2`。它为生成应用组合固定的完整
syntax/data-model、resolution、bidi、stable 默认 registry 和 Node 26 JavaScript
provider。Stable function 范围为 `:string`、`:number`、`:integer`、`:offset`、
`:currency` 和 `:percent`；已经实现的 `:date`、`:time`、`:datetime` 仍为 Draft，
只被显式 experimental datetime profile 接受。

兼容 profile `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` 继续供旧项目读取，并且只在
该 profile 中保留私有 `:lampclaw:datetime`。省略 `messageProfile` 是 error
`I18N1003`；旧 standards v1 profile 产生 `I18N1004`。在 1.0 前迁移窗口内仍可显式
使用兼容 profile。逐步
操作见 [message profile 迁移指南](docs/message-profile-migration.zh-CN.mbt.md)。精确能力
矩阵和固定上游快照见
[`docs/mf2-profile.zh-CN.mbt.md`](docs/mf2-profile.zh-CN.mbt.md)。

工具可以通过 `parse_mf2_syntax`、`parse_valid_mf2_model`、
`serialize_mf2_model`、`mf2_model_to_json` 和 `parse_mf2_model_json` 单独使用
`unicode-mf2-ldml48.2-syntax-v1`。该 profile 通过固定上游的全部 syntax 与
data-model fixture。独立的 `unicode-mf2-ldml48.2-resolution-v1` profile 增加
`Mf2FormattingContext`、`Mf2Input`、`format_mf2_standalone` 与
`format_mf2_model_standalone`，并同时返回 best-effort 文本、structured part 与 typed
error。`unicode-mf2-ldml48.2-default-functions-v1` 增加 stable required registry、
Node 26 `Intl` adapter 与公开 namespaced custom registry。机器可读矩阵覆盖 77 条
anchored normative requirement、全部 6 个 stable function 和 40 个 stable option；
独立 suite 记录 20 个 stable 与 4 个 experimental case，没有无法解释的 semantic
failure；同一上游 suite 还会在 Chromium、Firefox、WebKit 运行。详见
[语法与 interchange 指南](docs/mf2-syntax-data-model.zh-CN.mbt.md)。

Resolution、bidi、安全 structured output 与严格 locale 边界详见
[resolution 与 formatting 指南](docs/mf2-resolution-formatting.zh-CN.mbt.md)。
默认函数 authoring、backend 边界与 custom handler 见
[默认函数指南](docs/mf2-default-functions.zh-CN.mbt.md)。

限制包括：1,000 个 locale、64 MiB locale 总输入、64 MiB 生成 MoonBit、
16 MiB/100,000 条消息的 catalog、每条 source message 和 standalone 格式化输出 64
KiB，以及每个 message 64 个参数、input 或 rich tag。

## 示例与底层 API

源码仓库中的
[`examples/rabbita_todo`](https://github.com/lampclaw/moonbit-i18n/tree/v0.9.0/examples/rabbita_todo)
演示完整浏览器流程。示例刻意排除在发布 archive 外，registry 页面专注于库本身。

框架与 generator 维护者可以使用有文档的 `runtime` 与 `generator` package；普通应用
应优先使用生成 facade。见
[`docs/runtime-spi.zh-CN.mbt.md`](docs/runtime-spi.zh-CN.mbt.md)。

## 许可证

Apache-2.0
