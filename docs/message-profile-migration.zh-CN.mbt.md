# Message profile 迁移

[English](message-profile-migration.mbt.md)

`0.8.0` 增加显式 `messageProfile` authoring 契约。新项目应使用：

~~~json
{
  "messageProfile": "unicode-mf2-ldml48.2-js-v1"
}
~~~

该 profile 把 canonical locale JSON 连接到固定 Unicode MF2 syntax/data model、
resolution 行为、默认 bidi isolation、stable 默认 registry 与 Node 26 JavaScript
formatter。Catalog format 仍是 version 2，但 profile 会参与 contract hash。因此不同
profile 的 catalog 与 binding 会明确失败，而不会被混用。

## 兼容窗口

省略 `messageProfile` 目前表示
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1`。生成会成功，同时输出 warning
`I18N1003`。如果项目需要一个不改变消息语义的中间提交，可以先显式填入这个精确值；
显式兼容 profile 不会仅仅因为它是 legacy 就产生 warning。

私有 `:lampclaw:datetime` 只在兼容模式有效，并产生 warning `I18N3003`；标准模式会用
error `I18N3004` 拒绝它。省略字段的兼容默认值只是临时策略，在 `1.0.0` 前会变为错误；
在路线图与 changelog 明确之前，这句话不承诺具体在哪个版本收紧。

## 推荐迁移步骤

1. 同时把库和 CLI 升级到 `0.8.0`。保持兼容模式运行一次 `generate`，审查全部 warning。
2. 可选：先显式添加 compatibility profile，并提交更新后的 generation manifest。这样可
   把工具链升级与消息语义迁移拆成两个可审查步骤。
3. 替换私有 datetime expression。应按输出意图选择标准函数，而不是只按旧函数名替换：

   - 只显示日期：
     `{$when :lampclaw:datetime dateStyle=medium timeZone=UTC}` 改为
     `{$when :date length=medium timeZone=UTC}`；
   - 只显示时间：使用 `:time precision=hour|minute|second`；
   - 同时显示日期与时间：使用 `:datetime dateLength=short|medium|long
     timePrecision=hour|minute|second`。

   标准日期/时间输入可以是生成的 `InstantMillis` 参数，也可以是严格 ISO literal。
   `hourCycle` 需要单独审查：standards-mode draft function 暴露
   `hour12=true|false`，因此不是所有旧 option 都存在通用的文本替换。
4. 把 `messageProfile` 改为 `unicode-mf2-ldml48.2-js-v1`，并在同一变更中重新生成
   binding、generation manifest、deployment manifest 和全部 catalog chunk。
5. 运行 `check`、JavaScript 测试和生产 build。检查比较原始 string 的断言：规范 bidi
   isolation 可能在 expression 周围加入不可见 FSI/LRI/RLI 与 PDI 控制字符。
6. 把生成 JavaScript 与全部动态 catalog 作为一个兼容发布整体部署。不能让旧 facade
   读取标准 profile catalog，也不能让标准 facade 读取 compatibility catalog。

类型安全的应用调用不变。`I18n::new`、生成 message enum、`Translator::t`、`try_t`、
rich parts、locale negotiation 与 namespace loading 保持原有应用层形状。生成 package
新增 `MESSAGE_PROFILE`，应用诊断和部署工具可以记录当前契约而无需复制字符串 literal。

## Authoring 边界

standards-mode generator 会在输出 catalog 前校验完整 message model、schema variable、
声明的 rich-markup 名称与固定默认 function 范围。生成应用消息不能使用私有或应用自定义
function。底层工具仍可通过 `Mf2FunctionRegistry` 注册带 namespace 的 custom
function，但该行为不属于生成 authoring profile，也不计入 Unicode conformance 声明。

Stable 默认 function 是 `:string`、`:number`、`:integer`、`:offset`、`:currency` 与
`:percent`。`:date`、`:time` 和 `:datetime` 已实现且可以使用，但在固定上游快照中仍是
Draft。如果 Unicode 未来稳定了不同契约，它们的 option/API surface 可能需要再次通过
显式 profile 迁移。

## 验证命令

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.8.0 generate \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.8.0 check \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.8.0 pseudo \
  --message-profile unicode-mf2-ldml48.2-js-v1 \
  localization/schema.json en-US localization/locales/en-US.json \
  en-XA localization/locales/en-XA.json

moon check --target js
~~~

editor 或 CI 集成可使用 `--diagnostic-format=json`。Warning 输出到 stderr，不改变成功
命令的退出状态。独立 `pseudo`、`export-xliff`、`import-xliff`、
`import-i18next` 与 `import-arb` 命令没有 config-file 参数，因此标准模式项目必须通过
`--message-profile` 显式传入同一 profile；省略该 option 会保留兼容 profile。对应的
generator API 暴露同名可选 `message_profile` 参数。
