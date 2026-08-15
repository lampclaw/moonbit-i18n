# Message profile 迁移

[English](message-profile-migration.mbt.md)

`0.9.0` 要求显式声明 message 契约，并把稳定 MF2 与实验 date/time 行为分开。不编写
date/time function 的新项目应使用：

~~~json
{
  "messageProfile": "unicode-mf2-ldml48.2-js-v2"
}
~~~

明确使用固定 Draft `:date`、`:time` 或 `:datetime` 的项目必须使用：

~~~json
{
  "messageProfile": "unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1"
}
~~~

两个 profile 都把 canonical locale JSON 连接到固定 LDML 48.2 MF2 grammar、data model、
resolution、默认 bidi isolation 与 Node 26 JavaScript formatter。Catalog format 仍是
version 2，但 profile 参与 contract hash；不匹配的 facade 与 catalog 会明确失败。

## 0.9 的变化

- 省略 `messageProfile` 现在是 error `I18N1003`，generation 不再猜测 compatibility
  语义；
- `0.8.x` profile `unicode-mf2-ldml48.2-js-v1` 仍可使用，但会输出 warning
  `I18N1004`，因为它混合了稳定与 Draft function；
- 稳定 v2 拒绝 `:date`、`:time` 与 `:datetime`，显式命名的 experimental extension
  接受它们；
- 原始 `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` 仍可用于有意的兼容。
  私有 `:lampclaw:datetime` 继续产生 warning `I18N3003`；standards profile 用
  `I18N3004` 拒绝该私有名称；
- 独立 `pseudo`、`export-xliff`、`import-xliff`、`import-i18next`、`import-arb` 命令
  必须传入 `--message-profile`。

## 从 0.8.x standards authoring 迁移

1. 检查 locale source 中是否含 `:date`、`:time`、`:datetime`；
2. 如果都没有，把 config 改为 `unicode-mf2-ldml48.2-js-v2`；
3. 如果确实需要其中任意一项，选择
   `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1`，并记录该 authoring surface
   可能在 Unicode 稳定这些 function 时变化；
4. 同时把库与 CLI 升级到 `0.9.0`，并在同一变更中重新生成 binding、generation
   manifest、deployment manifest 与所有 catalog chunk；
5. 部署前运行 `check`、JavaScript test、浏览器/应用 test 与 production build，并把
   生成代码和 catalog 一起发布。

保留旧 v1 只是短期迁移桥梁，不是推荐的长期状态；warning `I18N1004` 会持续暴露这项
迁移债务。

## 从 compatibility profile 迁移

若当前目标是保持旧行为，可以继续显式使用 compatibility identifier。迁移到 standards
authoring 时：

1. 按输出意图替换私有 datetime expression：

   - 只显示日期：`{$when :date length=medium timeZone=UTC}`；
   - 只显示时间：使用 `:time precision=hour|minute|second`；
   - 同时显示日期与时间：使用 `:datetime dateLength=short|medium|long
     timePrecision=hour|minute|second`。

2. 仍含这些 Draft function 时选择 experimental datetime profile；移除三项后才能选择
   stable v2；
3. 单独审查 `hour12`、`timeZone` 与输入类型，不要盲目文本替换。输入可以是生成的
   `InstantMillis` 参数或严格 ISO literal；
4. 重新生成，并原子部署 facade 与全部 catalog chunk。

类型安全的应用调用不变。`I18n::new`、生成 message enum、`Translator::t`、`try_t`、
rich parts、locale negotiation 与 namespace loading 保持原有应用层形状。生成 package
导出 `MESSAGE_PROFILE`，供诊断和部署 metadata 使用。

## 验证命令

~~~bash
moon add lampclaw/i18n@0.9.0
moon add --bin lampclaw/i18n/cmd/i18n@0.9.0

moonx lampclaw/i18n/cmd/i18n@0.9.0 generate \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.9.0 check \
  localization/config.json localization/schema.json localization/locales \
  i18n public/i18n

moonx lampclaw/i18n/cmd/i18n@0.9.0 pseudo \
  --message-profile unicode-mf2-ldml48.2-js-v2 \
  localization/schema.json en-US localization/locales/en-US.json \
  en-XA localization/locales/en-XA.json

moon check --target js
~~~

Editor 或 CI 集成可使用 `--diagnostic-format=json`。Warning 写入 stderr，并保持退出状态
为 0。为保持源码兼容，底层 generator API 的可选 `message_profile` 参数仍默认
compatibility；新的 API caller 应始终显式传值。
