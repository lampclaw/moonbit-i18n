# 严格的 MF2 派生 profile

[English](mf2-profile.mbt.md)

`0.1.0-rc.2` 使用 `lampclaw-mf2-strict-v1+lampclaw-datetime-v1`。这是一个从
MessageFormat 2 概念派生、带版本的项目 profile，不表示完整通过 Unicode
MessageFormat 2。

上游比较基线固定为 Unicode MessageFormat WG 的
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027)，
日期为 2026-06-11。不可变 pin 与机器可读矩阵位于 `tests/unicode-mf2/`。

## 兼容矩阵

| 领域 | `0.1.0-rc.2` 契约 |
|---|---|
| Pattern 与 literal | 文本、转义、quoted literal 和 profile 支持的 unquoted literal 语法 |
| 变量 | 生成的 `String`、`Int`、`Double`、`Bool`、`InstantMillis` 类型契约 |
| 复杂消息 | 按行解析 `.input`、`.local`、`.match`；每个 matcher 必须有全通配 fallback |
| 选择 | profile 声明的精确数值、字符串、cardinal/ordinal、integer 和 offset 选择 |
| Markup | 通过结构化 parts 支持配对的开闭标签与 standalone 标签；文本格式化拒绝 markup |
| Function | `:string`、`:number`、`:integer`、`:offset` 和项目扩展 `:lampclaw:datetime` |
| 错误 | 编译/安装失败或结构化格式化失败；不执行 Unicode MF2 fallback-value 恢复 |
| Unicode 规范化 | 不提供完整的 NFC identifier/key 规范化 |
| 方向性 | 支持 catalog direction 元数据，但不实现 Unicode MF2 bidi isolation 算法 |
| Attribute 与 `u:` option | 拒绝 |
| 标准日期时间 registry | 拒绝 `:date`、`:datetime`、`:time`；项目扩展接收 epoch 毫秒 |
| 可选/自定义 registry | 拒绝 `:currency`、`:percent`、测试 function 和任意用户 function |
| 复杂空白语法 | 拒绝紧凑 declaration/variant；项目语法刻意采用按行形式 |

## 变更纪律

profile 标识参与每个 catalog 的契约哈希。任何语义扩展或不兼容收紧都必须更改标识，
并重新生成全部产物。CI 会检查 runtime 常量、参考 pin、矩阵、测试与文档保持同步。
