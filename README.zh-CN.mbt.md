# lampclaw/i18n

[English](README.mbt.md)

`lampclaw/i18n` 是一个小型的 MoonBit 内存国际化运行时。它负责规范化 locale
code、解析父级 locale、查找一个配置的 fallback locale，同时让 core API
保持与 UI 框架和应用业务消息类型无关。

~~~text
应用消息枚举（可选）
  -> 稳定的字符串消息 ID
  -> Translator.translate(id)
  -> 请求 locale 及其父级 locale
  -> fallback locale 及其父级 locale
  -> 已安装的内存 Catalog
  -> String? 结果
~~~

版本 `0.0.1` 是尚未发布的 pre-1.0 版本。JSON 资源加载、消息插值、复数规则、
消息提取和代码生成不属于当前版本。

## 从 checkout 使用

在模块发布到 Moon registry 之前，将本仓库和应用放进同一个 Moon workspace。
例如：

~~~text
workspace/
  moon.work
  moonbit-i18n/
  my-app/
~~~

公共的 `moon.work` 同时列出两个 module：

~~~toml
members = [
  "./moonbit-i18n",
  "./my-app",
]
~~~

在 `my-app/moon.mod` 中加入 module 依赖：

~~~toml
import {
  "lampclaw/i18n@0.0.1",
}
~~~

然后在需要国际化能力的应用 package 中导入：

~~~toml
import {
  "lampclaw/i18n",
}
~~~

`lampclaw/i18n` 发布后，可以用 registry 安装替代本地 workspace checkout：

~~~bash
moon add lampclaw/i18n
~~~

package import 保持不变。

## Core 运行时

用一个 fallback locale 创建运行时，安装 catalog，再用 translator 查询消息
ID：

~~~moonbit nocheck
let i18n = @i18n.I18n::new(fallback_locale_code="en-US")
i18n.install_catalog(
  @i18n.Catalog::new(
    locale_code="en-US",
    entries=[
      { id: "common.hello", message: "Hello" },
      { id: "common.save", message: "Save" },
    ],
  ),
)
i18n.install_catalog(
  @i18n.Catalog::new(
    locale_code="zh-CN",
    entries=[{ id: "common.hello", message: "你好" }],
  ),
)

let t = i18n.translator("zh-CN")
let hello = t.translate("common.hello") // Some("你好")
let save = t.translate("common.save") // 通过 en-US 得到 Some("Save")
let missing = t.translate("common.missing") // None
~~~

`Translator::translate` 返回 `String?`，由应用决定如何展示或上报缺失消息。
再次安装相同规范化 locale code 的 catalog 会替换原 catalog。

## Locale 解析

Locale code 会在存储和查找之前规范化：

~~~moonbit nocheck
@i18n.normalize_locale_code("ZH_hans_cn") // Ok("zh-Hans-CN")
@i18n.locale_lookup_chain("zh-Hans-CN") // ["zh-Hans-CN", "zh-Hans", "zh"]
~~~

规范化会将语言转为小写、四字符 script 转为首字母大写、两字符或数字 region
转为大写，并同时接受 `_` 和 `-` 分隔符。空分段和包含非 ASCII 字母数字字符的
分段会被拒绝。

运行时提供两个 translator 构造方法：

- `i18n.translator(code)` 保留规范化后的请求 locale；消息查找依次搜索该
  locale、它的父级以及配置的 fallback 链。
- `i18n.translator_from_code(code)` 先与已经安装的 catalog locale 协商，选择
  已安装的父级 locale 或 fallback，适合需要在 UI 中展示实际选中 locale 的
  场景。

`resolve_locale_code(requested, supported, fallback)` 将相同的 locale 协商能力
开放给应用的 locale 偏好列表。

## 应用侧类型层

Core 运行时有意使用字符串 ID，因为每个应用都拥有自己的 locale 集合和消息
schema。应用可以在运行时前增加穷尽枚举：

~~~moonbit nocheck
///|
pub(all) enum I18nText {
  Common(CommonText)
  Auth(AuthText)
}

///|
pub(all) enum CommonText {
  Hello
  Save
}

///|
pub(all) enum AuthText {
  Login
}
~~~

[Typed 示例](examples/typed) 将每个枚举值映射到稳定字符串 ID，并为每个支持的
locale 提供消息。它由应用拥有的 wrapper 暴露简洁 API：

~~~moonbit nocheck
let i18n = I18n::new(fallback_locale=EnUS)
let t = i18n.translator(ZhCN)
t.t(Common(Hello))
t.t(Auth(Login))
~~~

这些 `Locale`、`I18nText`、typed `I18n` 和 typed `Translator` 定义属于示例
应用；只导入 `lampclaw/i18n` 不会自动生成业务枚举。穷尽 `match` 会让新增消息
或 locale 直接暴露为 MoonBit 编译器需要处理的分支。

运行示例：

~~~bash
moon run --target js examples/typed
~~~

~~~text
你好
登录
~~~

## 架构

运行时只有四项职责：

1. `Catalog` 保存规范化 locale code 和一组 ID/message。
2. `I18n` 保存已安装 catalog 和配置的 fallback locale。
3. Locale helper 负责规范化 code、构建从具体到一般的查找链，并在请求 locale
   与支持 locale 之间协商。
4. `Translator` 先搜索请求链，再搜索 fallback 链，并返回第一条找到的消息。

Core package 不感知文件、JSON、浏览器、Rabbita 或应用枚举。资源加载和 typed
wrapper 保留在应用边界，因此命令行程序、服务端、测试和 UI 框架可以共享相同
查找运行时。

## 示例

### 基础 fallback

~~~bash
moon run --target js examples/basic
~~~

~~~text
zh-CN common.hello: 你好
zh-CN common.save (fallback en-US): Save
~~~

### Rabbita Web

独立的 [Rabbita Counter 示例](examples/rabbita_web/README.zh-CN.mbt.md) 基于
Rabbita 官方 Counter，加入 typed 消息 schema、本地化计数消息以及 `zh-CN` /
`en-US` 语言切换。它是独立 workspace module，因此 Rabbita 不会成为 core
`lampclaw/i18n` 的依赖。

~~~bash
cd examples/rabbita_web
moon install moonbit-community/warren@0.2.2
warren dev
~~~

打开 Warren 输出的 URL，改变计数并切换语言。示例 README 记录了已经验证的开发
服务器输出、浏览器检查项和 release build 流程。

## 仓库验证

在仓库根目录执行：

~~~bash
moon info && git diff --exit-code
moon fmt --check
moon check --target js
moon test --target js
moon run --target js examples/basic
moon run --target js examples/typed
~~~

测试覆盖 locale 解析、catalog 校验、MF2 格式化、typed enum 层以及独立的
Rabbita Counter 集成。

单独验证浏览器 release：

~~~bash
cd examples/rabbita_web
warren build --dist /tmp/moonbit-i18n-rabbita-counter
~~~

Warren 会生成 `index.html`、`index.js` 和 `styles.css`。输出目录是可丢弃的，
不会提交到仓库。

## 仓库结构

~~~text
i18n.mbt                    # Catalog、I18n 和 Translator 运行时
locale.mbt                  # 规范化和 locale 解析
examples/basic/             # 最小字符串 ID fallback 示例
examples/typed/             # 应用拥有的 typed enum 层
examples/rabbita_web/       # 本地化 Rabbita Counter 浏览器示例
~~~

## 许可证

Apache-2.0，参见 [LICENSE](LICENSE)。
