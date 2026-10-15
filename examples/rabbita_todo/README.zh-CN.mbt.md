# 生成式 i18n package · Rabbita Todo

[English](README.mbt.md)

这个浏览器示例基于 Rabbita 官方 Todo，展示完整的生成优先工作流。应用的维护源码
导入自己的生成 package 和应用拥有的浏览器 adapter，不直接导入 i18n runtime。

此示例使用 `0.9.3` 维护版本。下方命令使用匹配的本地 CLI，便于源码 checkout 重新生成产物。

## 生成与校验

在仓库根目录执行：

~~~bash
moon run --target wasm cmd/i18n -- generate \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n

moon run --target wasm cmd/i18n -- check \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n
~~~

两个 locale 当前都是 `28/28 (100%)`。生成器通过所有权 manifest 完整拥有
`i18n/` package 和 catalog 目录；两个目录由可恢复事务一起替换，`check` 是 CI 中的
只读漂移门禁。因为浏览器 contract 有意验证 Draft `:date`，这个示例显式使用
`unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` authoring；生成 catalog 会携带
该 profile 标识，runtime 会拒绝由其他 profile 生成的 catalog。不使用 date/time
function 的应用应改用 stable `unicode-mf2-ldml48.2-js-v2`。

## 运行

~~~bash
npm ci
cd examples/rabbita_todo
moon install moonbit-community/warren@0.4.5
warren dev --browser-entry main
~~~

release 构建：

~~~bash
warren build --browser-entry main --dist dist
~~~

Warren `0.4.5` 在 release 构建中使用随工具固定的 Evol minifier。浏览器验收仍固定
Node `26.7.0` 和 Playwright `1.62.1`。

## 架构

~~~text
localization/config.json + schema.json + locales/*.json
                         │
                         ▼
               moonx lampclaw/i18n/cmd/i18n generate
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
i18n/generated.mbt + moon.pkg  public/i18n/manifest.json + chunks
类型化 facade + 内嵌数据       namespace + SHA-256 + 契约 hash
              │
              ▼
main/moon.pkg 导入生成 i18n + browser_http + browser_preferences
              │                  │                  │
              ▼                  ▼                  ▼
Rabbita model / update / view  同源 fetch        localStorage / navigator
调用 Translator::t            应用 adapter       应用 adapter
~~~

生成 facade 负责 locale 协商、内嵌与动态 catalog、JavaScript `Intl` 格式化、
catalog 状态和诊断。业务代码使用
`@app_i18n.TodoUi(@app_i18n.ActiveCount(active))` 这样的类型化值。

JavaScript bundle 只内嵌英文 fallback catalog。第一次切换语言时，分别从
`/i18n/zh-CN--common.json` 和 `/i18n/zh-CN--todo_ui.json` 获取中文 `common`、
`todo_ui` namespace。应用先把精确 UTF-8 字节数和 SHA-256 与生成的 deployment
metadata 比较，再交给 facade 验证并安装。请求失败、integrity 不匹配或 chunk 无效时
保持当前 locale 不变，并显示可重试状态；retry 只重新请求缺失 namespace。示例有意
不加载 `contract` namespace，以验证常规的 message-level 英文 fallback。

每个 fetch 的 10 秒超时覆盖响应头和 body。流式读取按实际字节计数，执行 metadata
长度限制及 64 KiB 硬上限，并跨分段严格解码 UTF-8。失败时中止请求并取消 stream；
请求编号确保上一次失败请求的迟到结果不会影响同一 locale 的新一次尝试。

示例使用浏览器 `localStorage` 的
`lampclaw.i18n.rabbita-todo.locale` 保存用户明确选择的语言。启动时按“保存值、
`navigator.languages`、英文 fallback”的顺序协商。恢复中文偏好时，必须先成功
校验动态 catalog 才提交中文 locale，因此页面可能短暂显示内嵌英文的加载状态。
浏览器推断出的语言不会自动保存；只有用户主动切换或重试成功才形成长期偏好。
存储是尽力而为的能力：隐私策略或安全策略阻止存储时，当前会话仍可正常切换。
刷新会创建新的内存 `I18n` 实例，因此需要重新安装两个必要的中文 chunk；常规
HTTP 缓存仍可避免再次传输。Todo 项目数据本身有意不做持久化。

locale 检测、加载和持久化都是应用拥有的 adapter。生成 facade 接收 locale code
和 catalog 数据，但不访问浏览器存储，也不自行发起网络请求。示例中边界刻意收窄的
`browser_http/` package 只获取同源 catalog 文本，通过 Rabbita command 报告 HTTP
与网络失败，不把通用 HTTP client 链接进 release bundle。

小型 `contract/` package 是框架 adapter 和浏览器验收 fixture：它把结构化
`MessagePart` 转成 Rabbita HTML，并在三种支持的浏览器 engine 中验证 number、
datetime、rich parts、fallback 与 diagnostic。`main/` 中维护源码的本地化调用仍
只通过生成 facade；`browser_preferences/` 单独拥有宿主相关的偏好边界。

## 来源与许可证

UI 结构改编自
[Rabbita 官方 Todo 示例](https://github.com/moonbit-community/rabbita/tree/main/examples/todo)，
原项目使用 Apache-2.0。本示例改编与 `lampclaw/i18n` 同样使用 Apache-2.0。
