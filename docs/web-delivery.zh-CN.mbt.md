# 生产级 Web 交付

`lampclaw/i18n` 0.4 在不改变 canonical authoring 文件的前提下生成可独立部署的
catalog chunk。schema 顶层 message group 就是部署 namespace。译者仍然只维护每个
locale 一个 JSON 文件，不需要手工维护 chunk 或 hash。

## 生成目录

假设有 `en-US`、`zh-CN` 两个 locale，以及 `account`、`common` 两个 namespace，
CLI 会完整拥有如下输出目录：

~~~text
public/i18n/
├── manifest.json
├── en-US--account.json
├── en-US--common.json
├── zh-CN--account.json
└── zh-CN--common.json
~~~

每个 chunk 仍使用 catalog v2，并增加 `namespace` 字段；其中每个 message ID 都必须
以声明的 namespace 开头。`manifest.json` 记录 catalog version、profile、contract
hash、fallback/embedded locale，以及每个 chunk 的 path、UTF-8 字节数、SHA-256、
message 数量、方向、locale 和 namespace。所有数组与路径都按确定性顺序输出。

生成 facade 提供类型化的 `CatalogNamespace`：

~~~moonbit nocheck
let i18n = @app_i18n.I18n::new()
match i18n.install_catalog_chunk_source(
  @app_i18n.ZhCN,
  @app_i18n.CatalogAccount,
  verified_source,
) {
  Ok(_) => ()
  Err(message) => println("chunk rejected: \{message}")
}

if i18n.has_catalog_namespace(
  @app_i18n.ZhCN,
  @app_i18n.CatalogAccount,
) {
  // account 路由现在可以使用中文消息。
}
~~~

只有生成出的全部 namespace 都已安装时，`has_catalog(locale)` 才返回 true。只需要
部分路由的应用应使用 `has_catalog_namespace`。缺失 namespace 或 message 会继续走
常规 locale/fallback 链。格式损坏、contract 过期、profile/locale/namespace 不匹配，
或与同一 locale 已安装 catalog 的 direction 冲突的 chunk，会在替换现有可用数据之前
被拒绝。

为兼容旧用户，whole-locale catalog v2 仍然可解析、安装；新的 CLI 输出采用 chunk
和 deployment manifest。

## 应用拥有的加载配方

runtime 有意不包含 HTTP、storage、service worker 或 retry 策略。应用应当重新验证
`manifest.json`，按当前路由挑选必要 namespace，校验响应的精确字节，严格解码
UTF-8，最后把 source 交给生成 facade。

下面是与框架无关的浏览器侧 helper：

~~~javascript
const hex = bytes =>
  [...new Uint8Array(bytes)]
    .map(value => value.toString(16).padStart(2, "0"))
    .join("");

async function fetchVerifiedChunk(baseURL, entry, retry = true) {
  const response = await fetch(new URL(entry.path, baseURL), {
    cache: retry ? "default" : "reload",
  });
  if (!response.ok) throw new Error(`catalog HTTP ${response.status}`);
  const bytes = await response.arrayBuffer();
  if (bytes.byteLength !== entry.bytes) {
    if (retry) return fetchVerifiedChunk(baseURL, entry, false);
    throw new Error("catalog byte count mismatch");
  }
  const digest = hex(await crypto.subtle.digest("SHA-256", bytes));
  if (digest !== entry.sha256) {
    if (retry) return fetchVerifiedChunk(baseURL, entry, false);
    throw new Error("catalog SHA-256 mismatch");
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
}

async function loadRouteNamespaces(baseURL, locale, names, install) {
  const response = await fetch(new URL("manifest.json", baseURL), {
    cache: "no-cache",
  });
  if (!response.ok) throw new Error(`manifest HTTP ${response.status}`);
  const manifest = await response.json();
  const entries = names.map(name => {
    const entry = manifest.chunks.find(
      value => value.locale === locale && value.namespace === name,
    );
    if (!entry) throw new Error(`missing catalog chunk: ${locale}/${name}`);
    return entry;
  });
  const sources = await Promise.all(
    entries.map(entry => fetchVerifiedChunk(baseURL, entry)),
  );
  // install 桥接到 install_catalog_chunk_source；所有必需 chunk 成功后
  // 才提交 locale 切换。
  entries.forEach((entry, index) => install(entry, sources[index]));
}
~~~

推荐策略：

- 加载期间继续使用内嵌 fallback locale；
- 重新验证小型 manifest，让常规 HTTP cache 服务 chunk；
- integrity 不匹配时绕过 cache 重试一次，之后明确失败；
- chunk 独立安装，但只有当前视图需要的全部 namespace 成功后才提交路由或 locale；
- retry 时复用已经验证的 chunk；
- 把网络、integrity 和 runtime rejection 写入应用 telemetry，但不要记录含用户数据的
  翻译内容。

维护中的 Rabbita Todo 示例遵循这一边界：内嵌英文，独立请求中文 `common` 和
`todo_ui` chunk；失败时保留英文，只重试缺失 chunk，并且只有两个必要 namespace
都通过后才持久化显式语言选择。

## 公开的 release 预算

release gate 会读取生成 manifest、验证每个 chunk hash，并强制以下上限：

| 产物 | 预算 |
| --- | ---: |
| 浏览器 release JavaScript | 448 KiB |
| gzip 后的浏览器 JavaScript | 128 KiB |
| 所有 embedded-locale chunk | 8 KiB |
| 单个动态 namespace chunk | 64 KiB |
| deployment manifest | 64 KiB |

使用固定 release 工具链时，0.8 standards-profile reference application 实测为：
JavaScript 429 KiB、gzip 116 KiB（Brotli 76 KiB）、embedded-locale chunk 合计
2.0 KiB、最大动态 chunk 1.1 KiB、manifest 2.1 KiB。raw/gzip 上限相对 0.4
compatibility baseline 增加，是因为浏览器要安装 standards catalog，就必须保留完整
MF2 syntax/data-model 校验器、resolver、bidi 行为和默认 function dispatch；仅生成期代码
仍不可达。这些经过检查的值是防止回退的 ceiling，不代表所有应用 bundle 都具有相同
体积。

0.4 不新增 framework-specific package：目前还没有两个独立消费者需要同一套
lifecycle adapter、且有明确维护者负责它的证据。
