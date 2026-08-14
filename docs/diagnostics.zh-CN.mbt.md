# Authoring 诊断契约

[English](diagnostics.mbt.md)

`0.2.0` 引入 diagnostic contract version `1`。人类可读输出用于终端；在命令名后
添加 `--diagnostic-format=json` 可选择 JSON。集成必须按 `code` 分支，不能解析英文
message。

每条诊断包含 severity、调用者可见的源路径和半开 span。line/column 从 1 开始，
`byteOffset` 是从 0 开始的 UTF-8 偏移。parser 无法安全缩小位置时会报告整个有界
source，而不会伪造精度。

## 稳定错误码

| Code | 含义 |
|---|---|
| `I18N0001` | CLI 用法、文件系统、所有权或事务失败 |
| `I18N1001` | config JSON 非法 |
| `I18N1002` | config 值或关系非法 |
| `I18N2001` | schema JSON 非法 |
| `I18N2002` | schema 值或生成名称契约非法 |
| `I18N3001` | message 语法或 message contract 非法 |
| `I18N3002` | locale 资源或 locale 关系非法 |
| `I18N4001` | 未达到发布覆盖率要求 |
| `I18N5001` | 其他确定性生成失败 |
| `I18N9001` | 超出已配置资源限制 |

在 `0.x` 期间 code 只增不改。severity 和 span 精度可以在不改变 code 的情况下收紧；
语义重新分配必须使用新 code。`generator.generate_with_diagnostics` 在内存中公开同一
结构化契约；现有返回 string error 的 generator 函数保留为兼容适配层。

## JSON 结构

~~~json
{
  "diagnosticVersion": 1,
  "code": "I18N3001",
  "severity": "error",
  "message": "invalid MF2 message: zh-CN.common.hello: unknown variable: name",
  "path": "localization/locales/zh-CN.json",
  "span": {
    "start": { "byteOffset": 0, "line": 1, "column": 1 },
    "end": { "byteOffset": 42, "line": 2, "column": 1 }
  }
}
~~~
