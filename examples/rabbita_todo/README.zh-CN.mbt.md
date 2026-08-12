# 生成式 i18n package · Rabbita Todo

[English](README.mbt.md)

这个浏览器示例基于 Rabbita 官方 Todo，展示完整的生成优先工作流。应用的维护源码
只导入自己的生成 package，不直接导入 i18n runtime。

## 生成与校验

在仓库根目录执行：

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 generate \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n

moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 check \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n
~~~

两个 locale 当前都是 `28/28 (100%)`。生成器通过所有权 manifest 完整拥有
`i18n/` package 和 catalog 目录；两个目录由可恢复事务一起替换，`check` 是 CI 中的
只读漂移门禁。

## 运行

~~~bash
cd examples/rabbita_todo
moon install moonbit-community/warren@0.2.2
warren dev
~~~

release 构建：

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-todo
~~~

## 架构

~~~text
localization/config.json + schema.json + locales/*.json
                         │
                         ▼
               moonx lampclaw/i18n/cmd/i18n generate
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
i18n/generated.mbt + moon.pkg  public/i18n/*.json
类型化 facade + 内嵌数据       catalog v2 + 契约 hash
              │
              ▼
main/moon.pkg 导入 lampclaw/i18n_rabbita_todo/i18n
              │
              ▼
Rabbita model / update / view 调用 Translator::t
~~~

生成 facade 负责 locale 协商、内嵌与动态 catalog、JavaScript `Intl` 格式化、
catalog 状态和诊断。业务代码使用
`@app_i18n.TodoUi(@app_i18n.ActiveCount(active))` 这样的类型化值。

JavaScript bundle 只内嵌英文 fallback catalog。第一次切换语言时从
`/i18n/zh-CN.json` 获取中文 catalog，完成校验和原子安装后复用，不再重复请求。
请求失败或 catalog 无效时保持当前 locale 不变，并显示可重试状态。

小型 `contract/` package 是框架 adapter 和浏览器验收 fixture：它把结构化
`MessagePart` 转成 Rabbita HTML，并在三种支持的浏览器 engine 中验证 number、
datetime、rich parts、fallback 与 diagnostic。`main/` 中维护的业务源码仍只导入
生成 facade。

## 来源与许可证

UI 结构改编自
[Rabbita 官方 Todo 示例](https://github.com/moonbit-community/rabbita/tree/main/examples/todo)，
原项目使用 Apache-2.0。本示例改编与 `lampclaw/i18n` 同样使用 Apache-2.0。
