# Authoring 诊断契约

[English](diagnostics.mbt.md)

Diagnostic contract version `1` 在整个 `0.x` 保持稳定。人类可读输出用于终端；在命令名
后添加 `--diagnostic-format=json` 可选择机器可读输出。集成必须按 `code` 分支，不能解析
英文 message。

每条诊断包含 severity、调用者可见的源路径和半开 span。line/column 从 1 开始，
`byteOffset` 是从 0 开始的 UTF-8 偏移。Parser 无法安全缩小位置时会报告整个有界 source，
不会伪造精度。

成功命令也可能向 stderr 写入迁移 warning；它们保持退出状态为 0，且不改变生成输出。
JSON mode 对每个 warning 输出一个完整 diagnostic object；consumer 应把 stderr 当作 JSON
value 序列，而不是一个外层 array。

## 稳定 code

| Code | Severity | 含义 |
|---|---|---|
| `I18N0001` | Error | CLI 用法、文件系统、所有权或事务失败 |
| `I18N1001` | Error | config JSON 非法 |
| `I18N1002` | Error | config 值或关系非法 |
| `I18N1003` | Error | 省略必填 `messageProfile` |
| `I18N1004` | Warning | 选择 legacy standards profile v1；应迁移到 stable v2 或显式 datetime extension |
| `I18N2001` | Error | schema JSON 非法 |
| `I18N2002` | Error | schema 值或生成名称契约非法 |
| `I18N3001` | Error | message 语法或 message contract 非法 |
| `I18N3002` | Error | locale 资源或 locale 关系非法 |
| `I18N3003` | Warning | compatibility message 使用私有 `:lampclaw:datetime` |
| `I18N3004` | Error | standards-mode message 包含私有 `:lampclaw:datetime` |
| `I18N4001` | Error | 未达到发布覆盖率要求 |
| `I18N5001` | Error | 其他确定性生成失败 |
| `I18N9001` | Error | 超出已配置资源限制 |

在 `0.x` 期间 code 只增不改。只有当旧操作在新规则下本来也不可能成功时，severity 才能
像 `0.9.0` 的 `I18N1003` 收紧那样变化；语义重新分配必须使用新 code。
`generator.generate_with_diagnostics` 在内存中公开同一结构化契约；现有返回 string error
的 generator function 保留为兼容适配层。

## JSON 结构

~~~json
{
  "diagnosticVersion": 1,
  "code": "I18N1003",
  "severity": "error",
  "message": "messageProfile is required; choose an explicit authoring profile",
  "path": "localization/config.json",
  "span": {
    "start": { "byteOffset": 0, "line": 1, "column": 1 },
    "end": { "byteOffset": 128, "line": 8, "column": 1 }
  }
}
~~~
