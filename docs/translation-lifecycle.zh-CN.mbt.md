# 翻译生命周期与互操作

[English](translation-lifecycle.mbt.md)

本文定义稳定的翻译交换工作流。canonical locale JSON 仍是唯一的消息内容 authoring
格式。XLIFF 生命周期状态与 metadata 放在版本化 sidecar 中，生成和 runtime catalog
不会因此混入某个翻译工具专属的工作流字段。

## XLIFF 2.1 工作流

向翻译系统导出目标 locale：

~~~bash
moon-i18n export-xliff \
  --message-profile unicode-mf2-ldml48.2-js-v1 \
  localization/schema.json \
  en-US localization/locales/en-US.json \
  fr localization/locales/fr.json \
  build/fr.xlf
~~~

翻译完成后导入 XLIFF：

~~~bash
moon-i18n import-xliff \
  --message-profile unicode-mf2-ldml48.2-js-v1 \
  localization/schema.json \
  en-US localization/locales/en-US.json \
  fr build/fr.xlf \
  localization/locales/fr.json
~~~

命令始终写入三个互不相同的文件。未覆盖路径时，两个 sidecar 位于 locale 输出旁：

~~~text
localization/locales/fr.json
localization/locales/fr.json.xliff-state.json
localization/locales/fr.json.xliff-report.json
~~~

可在位置参数前通过 `--state-output` 与 `--report-output` 指定其他路径。下次导出时，
用 state sidecar 恢复已审核状态与译者上下文：

~~~bash
moon-i18n export-xliff \
  --message-profile unicode-mf2-ldml48.2-js-v1 \
  --state localization/locales/fr.json.xliff-state.json \
  localization/schema.json \
  en-US localization/locales/en-US.json \
  fr localization/locales/fr.json \
  build/fr.xlf
~~~

state 文件使用 `stateVersion: 1` 和 `xliff-2.1-lampclaw-v1` profile。每个 unit
记录 canonical identity、精确 source、source SHA-256、target payload、XLIFF state、
note，以及下一次导出所需的受支持 metadata。使用 XLIFF 生命周期的项目应提交这个
交换产物。

标准 `initial`、`translated`、`reviewed`、`final` 状态存储在
`segment@state`。importer 仍接受旧 Lampclaw `target@state` 形状，报告这次规范化，
并按标准形状重新导出。source 和 target MF2 字段只能包含文本，inline XML 会被拒绝。

## Identity 与过期 source 安全

每个 XLIFF unit ID 都是 source identity。如果当前 source 文本与 unit source 不逐字节
相同，导入失败。如果 sidecar 中的 source/hash 或 target 不再匹配 canonical 资源，
带 sidecar 的导出也会失败。因此文本变化必须显式更新翻译生命周期；旧 reviewed
翻译不能静默保留状态。

rename 与 removal 必须提供版本化映射：

~~~json
{
  "version": 1,
  "renames": {
    "legacy.save": "common.save"
  },
  "removed": ["legacy.delete"]
}
~~~

在 `import-xliff` 中以 `--id-migrations migrations.json` 传入。rename target 必须
存在于当前 schema，rename source 必须已不存在，target 不能冲突，当前 schema ID
也不能标记 removed。removed unit 的 payload 会被有意丢弃，并作为 loss 写入报告。

## Metadata 与 loss report

exchange sidecar 保留 file identity/original path、unit name 与翻译标志、segment
identity/state/substate、`xml:space`，以及 note 文本和其 `id`、`category`、
`appliesTo`、`priority`。schema description 会作为 source description note 导出；
译者添加的 note 可以通过 import/export round trip 保留。

不支持的 attribute、扩展 namespace 声明、comment、processing instruction 和显式
removed unit 都不会被静默丢弃。每一项都会进入版本化 report，包含稳定 code、field、
人类可读 message 和 `loss: true`。不支持的 element 会直接被拒绝，因为无法保证其
顺序和语义可恢复。

公共 `import_xliff_with_state` API 一次返回 locale 内容、exchange state 和 report。
`import_xliff` 仅保留为 content-only 兼容适配器；需要生命周期的库集成应使用结构化
API。

## i18next 与 Flutter ARB 迁移

单向迁移命令始终要求独立的 report 输出：

~~~bash
moon-i18n import-i18next \
  --message-profile unicode-mf2-ldml48.2-js-v1 \
  localization/schema.json fr legacy/fr.json \
  localization/locales/fr.json build/fr-i18next-report.json

moon-i18n import-arb \
  --message-profile unicode-mf2-ldml48.2-js-v1 \
  localization/schema.json fr legacy/app_fr.arb \
  localization/locales/fr.json build/fr-arb-report.json
~~~

i18next importer 接受常见的嵌套或 dotted string key；当 schema 声明了 `name` 时，
把 `{{name}}` 转换成类型化 `{$name}`。plural/context suffix、带 formatter 的
interpolation、未知 key 和非 string value 会被省略并逐项报告 loss，不会近似转换。

ARB importer 接受精确 dotted identity，或在整个 schema 中唯一的 key；它校验
`@@locale`，并转换简单 `{name}` placeholder。ARB metadata 和 ICU plural/select
语法在 canonical locale JSON 中没有直接表示，因此会被报告，而不是静默近似。

PO/POT 迁移被刻意排除。只有完成书面 MF2 映射，并由真实消费者证明目标工作流的损失
足够低之后，才会考虑加入。

这些独立命令不会读取应用 config。应通过 `--message-profile` 传入应用的精确
`messageProfile`；省略时采用[迁移指南](message-profile-migration.zh-CN.mbt.md)所述的
临时兼容 profile 行为。公共 interchange API 提供对应的可选 `message_profile` 参数。

## 安全与运行限制

interchange 输入限制为 64 MiB、100,000 个 unit、16 层 element 和每个 unit 64 个
note。XML `DOCTYPE`、外部/内部 entity、非 XLIFF element namespace、重复 identity、
非法 state、不安全层级，以及 MF2 payload 内的 inline XML都会 fail closed。返回前
还会用同一 size budget 校验输出。
