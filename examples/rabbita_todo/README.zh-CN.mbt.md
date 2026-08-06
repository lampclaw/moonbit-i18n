# 生成式 i18n · Rabbita Todo

[English](README.mbt.md)

这个独立浏览器示例基于 Rabbita 官方 Todo，使用完整的 `lampclaw/i18n`
工作流：JSON schema 与 locale 资源、typed enum 生成、内嵌 catalog、MF2
参数、Intl 格式化，以及面向应用的 `t.t(...)` API。

## 生成并校验翻译

在仓库根目录执行：

~~~bash
moon run cmd/i18n -- generate \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales \
  examples/rabbita_todo/main/generated.mbt \
  examples/rabbita_todo/public/i18n

moon run cmd/i18n -- check \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales \
  examples/rabbita_todo/main/generated.mbt \
  examples/rabbita_todo/public/i18n

moon run cmd/i18n -- coverage \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales
~~~

当前资源报告 `en-US: 22/22 (100%)` 和 `zh-CN: 22/22 (100%)`。`check`
只读；当生成的 bindings 或 catalog 与已提交文件不一致时会失败。

## 开发运行

~~~bash
cd examples/rabbita_todo
moon install moonbit-community/warren@0.2.2
warren dev
~~~

打开 Warren 输出的 URL。添加、完成、筛选和删除待办，在中英文之间切换，并确认
顶部的进行中数量使用了本地化的参数消息。

release 构建：

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-todo
~~~

已验证的构建会将 `index.html`、`index.js`、`styles.css` 和生成的 locale
catalog 写入可丢弃的输出目录。

## 架构

~~~text
i18n/config.json + schema.json + locales/*.json
                    │
                    ▼
              cmd/i18n generate
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
main/generated.mbt       public/i18n/*.json
typed Locale/I18nText    带版本的 catalog
          │
          ▼
main/i18n.mbt → Translator::t(I18nText)
          │
          ▼
Rabbita model / update / view
~~~

生成文件负责 `Locale`、`I18nText`、消息参数转换、schema hash 和内嵌
catalog。`main/i18n.mbt` 是很薄的应用适配层；`main/main.mbt` 仍是普通
Rabbita 代码，使用 `t.t(TodoUi(ActiveCount(active)))` 这样的 API。

## 来源与许可证

UI 结构改编自
[Rabbita 官方 Todo 示例](https://github.com/moonbit-community/rabbita/tree/main/examples/todo)，
原项目使用 Apache-2.0。本示例改编与 `lampclaw/i18n` 同样使用 Apache-2.0。
