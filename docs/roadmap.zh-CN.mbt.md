# 产品路线图

[English](roadmap.mbt.md)

本文档定义 `lampclaw/i18n` 的产品方向。它是工程路线图，不是按日历日期作出的交付承诺。
只有达到验收门槛才能进入下一个里程碑；版本范围表达实施顺序和兼容边界，而不代表交付日期。

本文档的中英文版本共同构成一份公开契约，必须同步修改。具体版本已经发布的行为以
[当前 MF2 profile](mf2-profile.zh-CN.mbt.md) 为准，而不是以本路线图为准。
规划中的功能不能作为宣称 conformance 的依据。

## 产品定位与当前基线

`lampclaw/i18n` 的目标是成为 MoonBit 原生、生成优先、类型安全、标准驱动的国际化
基础设施，具有可移植核心和可替换的目标平台 formatter。

稳定版 `0.1.0` 基线已经超出原型阶段：

- 应用代码使用生成的类型安全 MoonBit facade，而不是裸字符串消息 ID；
- schema、locale 资源、生成源码、catalog 和所有权 manifest 构成确定性的 authoring
  与部署流程；
- runtime 支持 locale 协商、内嵌与动态 catalog、结构化失败与诊断、rich parts
  和有界资源使用；
- CLI 支持生成、校验、覆盖率、pseudo locale 和 XLIFF 2.1 交换；
- 发布门槛覆盖多个 MoonBit target、覆盖率、性能、打包、API 文档和全新模块消费。

当前生成的应用 facade 是 Web/JavaScript 产品，通过明确的 formatter 边界使用宿主
`Intl`。可移植 runtime 能在其他 MoonBit target 编译，但 locale-sensitive formatting
能力刻意保持有限。当前发布的
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1` profile 是严格的
MessageFormat 2 派生子集，不表示完整通过 Unicode MessageFormat 2。

近期主要用户是需要工程级本地化的 MoonBit Web 应用。框架和工具作者可以通过已记录的
runtime 与 generator 接口使用底层能力。完整的跨后端 locale formatting 是长期扩展，
不会阻塞 JavaScript conformance 目标。

## MoonBit 原生设计原则

1. **让非法应用调用难以表达。** 生成 enum、类型化参数并使用穷尽匹配。裸字符串 ID
   保留为底层集成界面，而不是应用的常规 API。
2. **有意识地使用 package 边界。** 应用导入自身生成的 package；可移植 evaluator
   与目标专属 formatter 分离；框架集成留在 core runtime 之外。
3. **共享逻辑，适配宿主。** parser、validation、selection、catalog contract 和
   diagnostic 保持可移植。JavaScript `Intl`、未来 CLDR provider、storage 和网络集成
   放在明确的 package 或由应用持有的 adapter 后面。
4. **确定性生成并提交产物。** 安装依赖不能执行不受信任的下游 generator。生成的
   MoonBit 和 catalog 必须可复现、可审查，并能使用 frozen dependency resolution。
5. **优先采用显式数据和错误。** 公共边界使用类型化值、`Result`、稳定错误类别和
   有界诊断，避免环境全局状态或静默近似。
6. **尊重可达性与产物体积。** 开发工具可以在同一 module 中被解析，但应用 package
   只有在代码可达时才链接 parser、XML、async 或 CLI。生成和部署产物保留可测量的
   体积与性能预算。
7. **把 Mooncakes 当作产品界面。** 精确依赖版本、`moonx` authoring、
   `README.mbt.md`、公共 API 注释、发布包内容和全新模块 smoke 都是发布要求。
8. **对语义进行版本化，而不只是文件。** MF2 profile、catalog wire format、生成
   API 和 authoring schema 都有明确标识符与迁移规则。不支持的标准行为必须拒绝，
   不能猜测。

这些原则符合 MoonBit 的 package 级构建、目标专属文件和共享核心/多目标工作流。参见
官方 [package 配置](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html)
与[多目标工作流](https://www.moonbitlang.com/blog/moonbit-multiple-targets)。

## 借鉴其他生态

| 生态 | 吸收 | 不照搬 |
|---|---|---|
| [Unicode MF2 与 ICU](https://www.unicode.org/reports/tr35/tr35-messageFormat.html) | 规范性语法与数据模型术语、默认函数、错误与 fallback 行为、Unicode/CLDR 语义和可追溯 conformance 测试。 | 把部分 grammar 描述成“MF2 compliant”，或者静默近似所选 profile 未实现的函数。 |
| [Paraglide JS](https://inlang.com/m/gerre34r/library-inlang-paraglideJs) | 编译期校验、类型安全消息函数、确定性生成，以及不可达时能够被消除的输出。 | 把 JavaScript 专属 runtime 模型或框架假设带入可移植 MoonBit core。 |
| [Flutter `gen_l10n`](https://docs.flutter.dev/ui/internationalization) | 显式资源契约、稳定的生成 API、延迟 locale 加载和可审查的输入/输出 manifest。 | 引入第二套 canonical ARB authoring 模型，或者把 core package 与一个 UI 框架耦合。 |
| [FormatJS](https://formatjs.github.io/docs/getting-started/message-extraction/)、[gettext](https://www.gnu.org/software/gettext/manual/gettext.html) 与 [Babel](https://babel.pocoo.org/en/latest/messages.html) | translator context、机器可读诊断、过期/废弃翻译处理、确定性 merge 流程和 TMS 交换。 | 用基于正则的源码抽取取代类型化 schema，或者向用户隐藏有损 round trip。 |
| [Fluent](https://projectfluent.org/fluent/guide/terms.html) | 面向 translator 的上下文、可复用术语和面向富 UI 的消息。 | 建立平行消息语言；可复用概念应通过 MF2 与类型化 schema 表达。 |
| [i18next](https://www.i18next.com/overview/plugins-and-utils) | locale detection、loading、cache 和框架 adapter 的清晰边界。 | core runtime 中的全局可变 locale 状态、无边界插件体系或强制网络/storage 依赖。 |

canonical authoring 模型继续是项目 JSON schema、config 和 locale 资源。除非未来路线图
明确改变这一决定，其他格式只是迁移或交换边界。

## 里程碑与兼容政策

路线条目的状态使用 `planned`、`experimental`、`stable`、`deferred` 或
`rejected`。新工作按照以下优先级推进：

1. 当前里程碑的正确性、安全性和回归问题；
2. 完成当前里程碑所需的验收门槛；
3. 下一里程碑的前置条件；
4. 只有在解除已测量的消费者阻塞时，才提前进行更后期工作。

在 `0.x` 阶段，公共 API 仍处于 1.0 之前，但兼容性是有意维护的：

- 删除或不兼容重命名通常至少提前一个 minor release 给出诊断和迁移文档；
- 语义扩展或不兼容的收紧必须改变 MF2 profile 标识符，并重新生成所有相关产物；
- 只有 wire shape 或 decoding contract 改变时才更换 catalog version，而不是每次
  profile 扩展都更换；
- 生成 API 保持确定性，无法避免的源码破坏必须提供生成代码迁移说明；
- 安全修复可以立即拒绝此前接受的不安全输入，但原因必须记录在 changelog 和
  profile 文档中。

## 短期：`0.1.x`——冻结 Web 基线

**状态：已在 `0.1.0` 稳定。** release candidate 在以下全部门槛通过后晋升为非
prerelease Web 基线。本阶段没有新增 MF2 语法或框架 package。

### 交付项

- 修复现有 authoring schema、strict-v1 profile、生成 facade、catalog v2、XLIFF
  profile、runtime 边界和 CLI 的缺陷。
- 在 Linux、macOS 和 Windows 上运行精确版本 Registry smoke，包括 `moon add`、
  固定版本 `moonx`、可选 `moon add --bin`、生成、JavaScript 运行和动态 catalog
  安装。
- 增加 Chromium、Firefox 和 WebKit 覆盖：locale 协商与切换、内嵌与动态 catalog、
  number/datetime formatting、rich parts、fallback 和 diagnostic。
- 保持维护中的浏览器示例和至少两个独立真实消费者通过本地化校验与 JavaScript build。
- 发布所支持的 MoonBit、Node.js 与浏览器矩阵，以及 `0.x` 兼容政策。
- 保留现有安全、覆盖率、性能、文档和发布包内容门槛。

### 出口门槛

`0.1.0` 在满足以下条件后发布：

- 没有已知的 P0/P1 Web 发布阻塞问题；
- 在所有受支持桌面 CI 系统上，对精确 registry 版本完成全新模块完整流程；
- 受支持浏览器通过可观察的应用场景；
- Mooncakes 正确显示 README、元数据和所有公共库 API 页面；无公共 API 的 CLI
  executable 则通过精确版本安装与执行验证；
- 当前 strict profile 已冻结并准确记录，且没有宣称完整 Unicode MF2；
- 维护中的消费者不依赖未发布的 workspace 或 submodule 源码。

## 中期：`0.2.x–0.4.x`——authoring 与 Web 交付

### `0.2.x`——authoring 与诊断

**状态：已在 `0.2.1` 稳定。** canonical JSON 格式和 strict-v1 runtime profile
保持不变；该版本只增加显式 authoring workflow、diagnostic 与可复现性契约。

- 增加 CLI scaffold，生成采用 canonical JSON authoring 布局和生成应用 package 的
  最小双语言模块。
- 为 CI 与编辑器集成增加稳定诊断代码、源文件路径与范围、人类可读输出和机器可读
  JSON 输出。
- 记录确定性的输入/输出 manifest，并验证输入未变化时生成操作不产生改动。
- 保持显式且适合提交的生成流程；不依赖消费者安装依赖时运行项目代码。

出口门槛：新用户可以在所有受支持 CLI 平台上完成 scaffold、generate、定位一条非法
消息、修复并构建应用；重复生成不产生 diff。

`0.2.1` 通过以下证据满足门槛：原子发布的双语言 scaffold；携带路径和 span 的稳定
human/JSON diagnostics；版本化 SHA-256 输入/输出 manifest；逐字节 check mode；以及
在锁内保留生成 interface 的真正 no-op 路径。clean-module 场景进入 package smoke 和
跨平台 Registry smoke 门禁。

最初的 `0.2.0` registry artifact 通过了 build 与文档检查，但 exact-version smoke
发现 scaffold 的 staging lock 留在用户 cache。该版本没有被覆盖；`0.2.1` 删除这些
不可达 lock，并作为被接受的 `0.2.x` 版本。

### `0.3.x`——翻译生命周期与互操作

**状态：已在 `0.3.0` 稳定。** canonical locale JSON 继续作为消息内容事实来源；
XLIFF 生命周期 metadata 由版本化 sidecar 承载，每一项有意损失都会形成机器可读报告。

- 扩展 XLIFF 交换，支持翻译状态、source identity、translator note、过期 source
  检测和安全的 ID rename/removal 处理。
- 提供从常见 i18next JSON 与 Flutter ARB 到 canonical 项目模型的确定性单向
  importer，并明确报告无法表达的语义。
- 只有在完成书面 MF2 映射且真实消费者证明满足目标流程所需的低损失要求后，才增加
  PO/POT 迁移。
- 尽可能保留未知但受支持的 XLIFF metadata，并报告每个有意丢弃的字段。

出口门槛：export/import round trip 保留消息 identity、source text、translator
context、state 和 MF2 payload；过期翻译不能被静默接受。

`0.3.0` 以标准 segment state、source SHA-256 identity、translator note、严格的
过期 source/target 检查、显式版本化 rename/removal map，以及确定性的 i18next/ARB
迁移报告达到该门槛。由于尚无书面低损失 MF2 映射和真实消费者证据，PO/POT 仍被排除。

### `0.4.x`——生产级 Web 交付

**状态：已在 `0.4.0` 稳定。** canonical authoring 仍是每个 locale 一个 JSON
resource。schema group 会成为可独立安装的 catalog-v2 chunk，确定性 deployment
manifest 携带精确字节数和 SHA-256 identity。fetch、cache、integrity retry、持久化和
locale commit 均由应用持有。

- 在不改变 canonical locale 源格式的前提下，生成面向 namespace 的 catalog chunk
  和确定性部署 manifest。
- 记录由应用持有的 loading、cache、integrity check、retry 与 fallback 配方。
  core runtime API 接收数据，但不负责 fetch 或 storage。
- 维护无框架浏览器示例，并测量生成 JavaScript、内嵌 locale 和动态 chunk 的体积预算。
- 只有至少两个独立消费者需要相同生命周期集成且存在明确维护者时，才增加框架专属
  package。

出口门槛：应用可以内嵌 fallback locale、独立延迟加载 chunk、拒绝不兼容或损坏的
chunk、通过文档化 fallback 恢复，并保持在公开体积预算内。

`0.4.0` 以类型化 namespace metadata、原子 chunk 合并、message-level fallback、
无框架加载配方、维护中浏览器示例的应用侧 integrity check、损坏/过期替换测试，以及
强制 raw/gzip 体积上限达到该门槛。由于尚未满足两个消费者和明确维护者的门槛，没有
新增 framework package。

## 中期：`0.5.x–0.8.x`——向 Unicode MF2 收敛

每个阶段引入一个新的版本化 message profile。旧 profile 在文档化迁移窗口内保持
可读；其中的私有扩展不能隐式变成标准行为。

### `0.5.x`——语法与数据模型

**状态：已在 `0.5.0` 稳定。** 独立的
`unicode-mf2-ldml48.2-syntax-v1` profile 已实现固定版本的完整 grammar、
well-formed/valid 分层、Unicode 16 NFC 等价名称处理、规范公共/JSON interchange
model，以及确定性、功能等价的语法序列化。vendored 上游覆盖包含全部 114 个接受语法、
133 个 syntax-error 和 23 个 data-model 用例。现有 catalog 仍使用 strict-v1，因此
本阶段不会提前替代 `0.8.x` 规划的显式 authoring 切换。

- 实现所固定稳定规范的完整 grammar，以及 well-formed 与 valid 的区别。
- 覆盖 compact message、declaration、expression、option、attribute、markup、
  reserved syntax、quoted form 和规范性 interchange data model。
- 应用要求的 NFC 等价名称处理，并确定性拒绝歧义或非法名称。

### `0.6.x`——resolution、错误与 Unicode 行为

**状态：已在 `0.6.0` 稳定。** 独立的
`unicode-mf2-ldml48.2-resolution-v1` profile 已实现按源码顺序且最多一次的
declaration resolution、规范多 selector ranking、best-effort fallback 与 typed error、
默认 bidi isolation、`u:id`/`u:dir`，以及不绑定 renderer 的 markup/attribute part。
严格 locale API 使用固定 IANA registry 完成 RFC 5646 canonicalization 与 RFC 4647
lookup；0.6 之前的 locale API 保留已记录的兼容面。固定上游的 67 个 fallback、
pattern-selection、bidi 与 Unicode-option fixture 在四个 MoonBit backend 全部通过。
该版本刻意把 stable 默认与公开 registry 留给下一阶段。

- 实现规范性的 declaration resolution、matcher selection、fallback value、
  error category 和 best-effort formatting 行为。
- 完成 BCP 47 locale canonicalization 与 negotiation 边界。
- 为文本和结构化 parts 实现 MF2 bidi isolation 要求。
- 在不允许不安全 renderer 行为的前提下，通过结构化输出保留 rich markup 与
  attribute。

### `0.7.x`——默认函数与 registry

**状态：已在 `0.7.0` 稳定。**
`unicode-mf2-ldml48.2-default-functions-v1` 实现全部固定 stable required function
（`:string`、`:number`、`:integer`、`:offset`、`:currency`、`:percent`）及所有 required
option、operand、selection rule 与 output 边界。路线图要求的 `:date`、`:time`、
`:datetime` 已实现，但在固定规范中仍明确为 Draft；Draft `:unit` 暂缓。Node 26
JavaScript provider 通过全部 124 个固定 function case。

- 实现所固定稳定默认 registry 要求的全部 function、option、operand、selection rule
  和 output behavior。
- 定义可移植 formatter/selector registry 接口，以及基于 `Intl` 的完整 JavaScript
  provider；宿主缺少所需语义时，只添加边界清晰的兼容代码。
- 支持带 namespace 的 custom function，但不能把任何 custom repertoire 纳入 Unicode
  conformance 声明。

### `0.8.x`——兼容与 conformance 收口

**状态：已在 `0.8.0` 稳定。** 聚合 profile
`unicode-mf2-ldml48.2-js-v1` 现在连接显式 canonical authoring、profile 专属 contract
hash、catalog-v2 安装、生成 facade 和 Node 26 standards runtime。省略设置会带
`I18N1003` warning 继续兼容；私有 datetime 只留在 compatibility mode，并有专属迁移
诊断。新 scaffold 和仓库维护的 Rabbita consumer 已使用不含私有 function 的 standards
mode。经检查的矩阵把 20 条 scope 内规范 requirement、6 个 stable function 与 40 个
stable option 映射到测试；24 个独立 differential case 在 Node 26.7.0 上没有无法解释的
semantic gap，同时保留独立的 CLDR-text 分类。standards-profile Rabbita build 实测
raw 429 KiB、gzip 116 KiB；显式 448/128 KiB 上限为 runtime validator 与 formatter
留出空间，同时继续阻止未经审查的后续增长。

- 增加显式 `messageProfile` authoring 配置。现有项目缺少该字段时起初按 strict-v1
  解释并给出迁移诊断；在 `1.0.0` 之前将其变为必填。
- `:lampclaw:datetime` 只保留在 legacy profile，并提供迁移到标准 `:datetime` 的
  诊断。
- 维护机器可读矩阵，把每条规范性要求和稳定默认 registry 条目映射到测试。
- 增加上游 fixture，并与独立 conforming implementation 做 differential test；
  宿主 CLDR 文本差异与语义失败分别归类。

这一版本范围的出口门槛是 JavaScript 上不存在无法解释的 conformance 缺口、维护中的
消费者迁移成功，且标准模式消息不依赖私有扩展。

`0.8.0` 通过生成 scaffold、Rabbita 浏览器 consumer、固定上游 suite、机器可读
requirement matrix 与独立 differential report 达到这个 scope 内门槛。这不会提前替代
`0.9.x` 为 1.0 声明选择并冻结精确最终 stable 目标的任务。

## 长期：`0.9.x` 与 `1.0.0`

### `0.9.x`——conformance release candidate

- 在阶段开始时固定所选的最新稳定 Unicode MF2/LDML 与 CLDR 精确版本。draft 功能
  继续作为单独命名的 experimental extension。
- 在 `1.0.0` release-candidate 周期内冻结这一目标，而不是跟随持续变化的上游 draft。
- 每条规范性要求必须标记为 `passed`、带公开理由的 `not applicable`，或明确的发布
  blocker。
- 在所支持的 Node.js、Chromium、Firefox 与 WebKit 矩阵上运行上游 fixture、项目
  regression test 和 differential test。
- 冻结 1.0 的公共 runtime、generator、authoring、catalog、registry 和生成 facade
  契约，并完成消费者迁移。

### `1.0.0` 中“完整 MF2”的定义

`1.0.0` 的声明刻意限定范围：

> `lampclaw/i18n` 的 JavaScript 后端符合该版本明确固定的稳定 Unicode
> MessageFormat 2 版本。

该版本必须同时满足：

- 完整实现所要求的语法、validity、data model、resolution、formatting、fallback
  和错误行为；
- 实现所固定 registry 中全部稳定且必需的默认 function、option、operand、selector
  和 output behavior；
- 实现所需的 Unicode normalization、locale、number/date/time、plural 和 bidi 行为；
- conformance 测试可追溯，且不存在无法解释的规范性缺口；
- 标准模式不依赖 `lampclaw:*` function 或其他私有扩展；
- custom function 和 structured parts 扩展点保持类型安全，其额外行为明确排除在
  Unicode conformance 声明之外；
- 为 1.0 公共界面记录兼容、弃用、profile 和 catalog 迁移政策。

可移植 core 必须继续在所有受支持 MoonBit 后端编译，并通过目标无关行为测试。
Native、Wasm 与 Wasm-GC formatter 可以继续保持有限或 experimental，在分别通过
自身 conformance 门槛前，不纳入 1.0 的完整 MF2 声明。

### `1.x` 及以后

- 先稳定可选 Native CLDR provider，再提供相应 Wasm/Wasm-GC provider；不能在 core
  runtime 中内嵌无边界的 CLDR payload。
- 在不改变无框架应用 facade 的前提下扩展 TMS、编辑器和框架集成。
- 只有真实消费者测量出依赖解析损害或版本冲突时，才重新评估把 runtime 与 authoring
  工具拆为不同 Mooncakes module。
- 后续稳定 MF2 版本通过显式 profile、兼容测试和迁移采用，不能静默改变 `1.0` 语义。

## 暂缓与拒绝的方向

以下内容不是近期产品工作：

- 自动或 AI 翻译，以及托管式翻译管理服务；
- runtime 持有的网络、浏览器 storage 或全局可变 locale 状态；
- 把 ARB、PO、Fluent 或 i18next JSON 作为平行 canonical authoring 格式；
- 使用正则从 MoonBit 源码抽取，或依赖不稳定的编译器内部接口；
- 把所有 MoonBit 后端的完整 CLDR formatting 作为 JavaScript 优先 `1.0.0` 的前置
  条件；
- 在当前单 module 依赖模型造成实质工程损害之前发布多个 module。

除非未来路线图将其提升，否则这些条目为 `deferred`。全局可变状态、静默近似标准和
不报告的有损转换属于 `rejected` 设计。

## 后续开发治理

修改公共 API、authoring format、MF2 profile、catalog contract、runtime、generator、
CLI 或受支持 target 前，提案必须说明：

1. 所服务的路线图里程碑和用户问题；
2. MoonBit package 与 target 边界；
3. 借鉴的生态先例，以及有意不照搬的内容；
4. 公共 API、兼容性、catalog/profile 与迁移影响；
5. 测试、性能/体积预算、消费者验证和发布门槛。

当前里程碑以外的变更必须有已测量的 blocker 或消费者需求。对路线图的有意偏离必须
在实现之前或同一提交中同步修改两种语言的路线图和 changelog。发布审查要确认 README
声明、MF2 matrix、实现状态与本路线图不存在冲突。

每个发布边界都要审查本文档。只有记录完成验收门槛后，工作状态才能从 `planned` 或
`experimental` 变为 `stable`；未完成工作可以后移，但不能降低门槛。
