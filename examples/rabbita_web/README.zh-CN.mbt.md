# 本地化 Rabbita Counter

[English](README.mbt.md)

这个独立浏览器示例基于 Rabbita 官方 Counter，展示手写 typed i18n 集成。
Rabbita model 同时保存计数值和 locale；view 通过 `t.t(...)` 翻译参数化消息，
英文复数选择由 `Intl.PluralRules` 完成。

~~~text
Rabbita Model(count, locale)
  -> 应用拥有的 I18nText 枚举
  -> typed Translator.t(I18nText)
  -> lampclaw/i18n 运行时 + JS Intl formatter
  -> Rabbita Val[Html]
  -> 浏览器 DOM
~~~

示例是独立的 Moon workspace module，因此 Rabbita 只是示例依赖，不会成为 core
runtime 的依赖。

## 环境要求

- 能构建本仓库 workspace 的 MoonBit toolchain。
- 安装 Warren 0.2.2，作为 Rabbita 开发服务器和 release 构建工具。

~~~bash
moon install moonbit-community/warren@0.2.2
~~~

## 开发运行

在当前目录执行：

~~~bash
warren dev
~~~

Warren 默认在 `http://127.0.0.1:4300` 提供应用，监听 MoonBit package，并在
文件变化后重新构建和刷新浏览器。

下面这次开发运行已经验证成功：

~~~text
➜  rabbita_web git:(main) warren dev
08:08    [info]: Running server on http://127.0.0.1:4300
08:08  [warren]: Building...
08:08    [moon]: Finished. moon: ran 17 tasks, now up to date
08:08  [warren]: moon build succeed at /home/luca/projects/lampclaw/moonbit-hackathon/moonbit-i18n/examples/rabbita_web/main.
08:08  [warren]: Changes detected. Reloading...
~~~

时间和任务数量是一次验证快照，后续增量构建可能不同。

## 浏览器验收

1. 打开 `http://127.0.0.1:4300`，确认初始 locale 是 `zh-CN`。
2. 点击增加和减少，确认计数值与本地化计数消息同步变化。
3. 点击语言按钮，确认 locale、按钮、标题和参数化计数消息切换为英文。
4. 将计数调整为一和二，确认英文分别显示 “One click” 和 “2 clicks”。
5. Warren 运行时修改 MoonBit 文件，确认成功重建后浏览器刷新。

## 自动验证

在仓库根目录或当前目录执行：

~~~bash
moon fmt --check
moon check --target js
moon test --target js
~~~

创建可丢弃的 release build：

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-counter
~~~

构建必须生成 `index.html`、`index.js` 和 `styles.css`。示例的 `dist/` 已忽略，
生成的浏览器产物不提交。

## 实现结构

- `main/i18n.mbt` 包含示例 enum、参数映射、catalog、runtime 和 typed wrapper。
- `main/main.mbt` 沿用 Rabbita Counter 的 typed message/update/view 结构，并在
  model 中加入 locale。
- `main/*_wbtest.mbt` 验证计数更新、复数消息、翻译和可逆 locale 切换。
- `public/` 包含 Warren 使用的 HTML shell 与 CSS。

本示例基于
[Rabbita 官方 Counter](https://github.com/moonbit-community/rabbita/tree/main/examples/counter)，
其许可证为 Apache-2.0。
