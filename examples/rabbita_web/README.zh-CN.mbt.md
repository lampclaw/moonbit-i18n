# Rabbita Web 示例

[English](README.mbt.md)

这个独立浏览器示例将 `lampclaw/i18n` 与 Rabbita 组合使用。Locale 和消息枚举
由应用拥有，运行时 catalog 由穷尽翻译构建，视图通过 `t.t(...)` 渲染消息。

~~~text
Rabbita Model.locale
  -> 应用拥有的 Locale 与 I18nText 枚举
  -> typed Translator.t(I18nText)
  -> lampclaw/i18n 字符串 ID 运行时
  -> Rabbita Val[Html]
  -> 浏览器 DOM
~~~

示例是独立的 Moon workspace module，它对 Rabbita 的依赖不会成为 core
`lampclaw/i18n` module 的依赖。

## 环境要求

- 能够构建本仓库 workspace 的 MoonBit toolchain。
- 一次性安装 Warren，作为 Rabbita 开发服务器和 release 构建工具。

~~~bash
moon install moonbit-community/warren
~~~

## 开发运行

在当前目录执行：

~~~bash
warren dev
~~~

Warren 默认在 `http://127.0.0.1:4300` 提供应用，监听 MoonBit package，在文件
变化后重新构建并刷新浏览器。

下面这次开发运行已经验证成功：

~~~text
➜  rabbita_web git:(main) warren dev
08:08    [info]: Running server on http://127.0.0.1:4300
08:08  [warren]: Building...
08:08    [moon]: Finished. moon: ran 17 tasks, now up to date
08:08  [warren]: moon build succeed at /home/luca/projects/lampclaw/moonbit-hackathon/moonbit-i18n/examples/rabbita_web/main.
08:08  [warren]: Changes detected. Reloading...
~~~

时间和任务数量是一次验证快照，后续增量构建可能报告不同数值。

## 浏览器验收

1. 打开 `http://127.0.0.1:4300`。
2. 确认初始 locale 为 `zh-CN`，页面显示中文。
3. 点击语言按钮，确认 locale 和所有消息切换为 `en-US` 与英文。
4. 再次点击，确认页面恢复到 `zh-CN`。
5. Warren 运行时修改一个 MoonBit 源文件，确认成功重建后浏览器刷新。

## 自动验证

在仓库根目录或当前目录执行 workspace 门禁：

~~~bash
moon fmt --check
moon check --target js
moon test --target js
~~~

当前 workspace 结果：

~~~text
Total tests: 23, passed: 23, failed: 0.
~~~

创建可丢弃的 release build：

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-web
~~~

构建必须成功，并生成：

~~~text
index.html
index.js
styles.css
~~~

示例的 `dist/` 目录已被忽略。验证产物应写入临时目录，不提交生成的浏览器
artifact。

## 实现结构

- `main/i18n.mbt` 包含应用 locale/message 枚举、穷尽翻译、运行时 catalog
  构建以及 typed translator wrapper。
- `main/main.mbt` 包含 Rabbita model、语言切换消息、view 和浏览器挂载点。
- `main/*_wbtest.mbt` 验证两种 locale 翻译和可逆的 locale 切换。
- `public/` 包含 Warren release build 会复制的维护中 HTML shell 和 CSS。

页面从 `ZhCN` 开始。每次渲染都会为 model 当前 locale 取得 translator，再调用
`t.t(Common(Hello))`、`t.t(Web(SwitchLanguage))` 等表达式。按钮发送一个 typed
Rabbita 消息，update 函数替换 locale，随后 Rabbita 重新计算 view。
