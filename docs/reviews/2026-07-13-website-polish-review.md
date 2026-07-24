# 审核反馈：feat/website-polish（2026-07-13）

> 本文件是对提交 `9aa28b8 feat(website): polish landing page branding and copy` 的 main 侧审核反馈。
> 接手 agent 请先读本文件，再按下方两个行动项处理。

## 审核基线

- 审核分支：`feat/website-polish`（HEAD `9aa28b8`）
- 对比基线：`origin/main` @ `2f858d1`
- 审核方式：独立复跑测试 + 逐项核对 diff + 安全/凭证扫描

## 总体结论

**技术层面通过。** 39/39 测试全绿，JS 语法 OK，`git diff --check` 通过，范围只碰 `website/`（零 App 代码改动），无新外部依赖/凭证/追踪器，app-icon.png 来源合规（复用 Android 真实启动图标）。

**但有 2 个文案层面的问题必须在合并前处理**（见下方行动项 1、2）。这是品牌/合规问题，不是代码缺陷。

---

## 行动项 1：补全 8 语言文案同步（必须做）

### 问题

提交 `9aa28b8` 只改了 **zh-CN** 的 hero 区域文案和隐私短句，将其从专业克制风格改为热情口语化风格。但 **en / es / fr / de / pt-BR / ja / ko 七个语言完全没动**，仍是旧文案。

后果：切换到英文/日文等语言时，用户看到的还是旧的"架好手机，专心做好每一次"风格，而中文变成了"来做俯卧撑吧！Just do it!"——**同一官网品牌声音分裂**。

现有测试 `"Chinese hero uses the approved headline and reassurance copy"` 只断言中文，不校验其他语言同步，所以测试通过 ≠ 一致性达标。

### 需要同步的 key（7 个）

以下 key 在 zh-CN 已改，需在其余 7 个语言改成**对应风格的翻译**（不是逐字翻译，是传递同样的品牌调性）：

| key | zh-CN 新文案（已改） | 各语言现状 |
|---|---|---|
| `meta.ogDescription` | 来做俯卧撑吧！AI识别计数,放心，Just do it! | 7 语言仍是旧的"架好手机，专心做好每一次" |
| `hero.titleAria` | 来做俯卧撑吧！ | 7 语言仍是旧的"Set up your phone. Focus on every rep."等 |
| `hero.titleLine1` | 来做 | 7 语言仍是"Set up your phone."等 |
| `hero.titleLine2` | 俯卧撑 | 7 语言旧值 |
| `hero.titleLine3` | 吧！ | 7 语言旧值 |
| `hero.lede` | AI识别计数,放心，Just do it! | 7 语言旧值 |
| `privacy.short` | 完全本地化的视觉识别，告别隐私风险。 | 7 语言旧值（**注意：此 key 的最终文案待行动项 2 决定后再统一**） |

### 各语言在 locales.js 中的行号定位

`website/locales.js` 里每个语言段的起始行（方便定位）：

| 语言 | 代码 | 大致行号区间 |
|---|---|---|
| 简体中文 | zh-CN | ~24–75（已改，作为参照） |
| English | en | ~140–195 |
| Español | es | ~286–340 |
| Français | fr | ~432–486 |
| Deutsch | de | ~578–632 |
| Português (BR) | pt-BR | ~724–778 |
| 日本語 | ja | ~870–924 |
| 한국어 | ko | ~1016–1070 |

> 精确行号以 `grep -n "'hero.lede'" website/locales.js` 等定位为准。

### 翻译要点

1. **调性对齐**：中文新文案是"热情、口语、号召行动"的风格（"来做俯卧撑吧！"）。各语言翻译要传递**同样的调性**，不是逐字翻译旧文案。
   - 例如英文 hero 不应再是 "Set up your phone. Focus on every rep."，而应是类似 "Let's do pushups!" 的号召式表达。
2. **titleLine 三行拼接**：`hero.titleLine1 + titleLine2 + titleLine3` 拼起来必须是一个通顺的完整句。中文是"来做"+"俯卧撑"+"吧！" = "来做俯卧撑吧！"。各语言要保证拼接后通顺。
3. **hero.lede 的 "Just do it!"**：这是英文短语，中文版直接嵌入了。其他语言可以保留 "Just do it!" 作为品牌口号（国际化产品常见做法），也可以本地化——由翻译者判断，但要在 7 语言间保持一致策略。
4. **`hero.eyebrow` 未改**：中文 `hero.eyebrow` 仍是"你的 AI 俯卧撑教练"，这次没动。如果新调性下 eyebrow 也要调整，一并处理；否则保持。

### 完成标准

- [ ] 7 个语言的上述 key 全部更新为新调性的翻译
- [ ] 新增/更新测试：**断言所有 8 个语言的 hero 文案风格一致**（不只是中文）。至少加一个测试遍历所有 locale，校验 titleLine 拼接通顺、lede 非空
- [ ] `node --test website/tests/website.test.mjs` 全绿
- [ ] `node --check website/locales.js` 通过

---

## 行动项 2：隐私短句措辞——与用户讨论最终决定（必须先讨论再做）

### 问题

`privacy.short` 从：

> **旧**：姿态识别在设备端完成 · 原始视频帧不上传

改成了：

> **新**：完全本地化的视觉识别，告别隐私风险。

两种措辞的差异：

| | 旧文案 | 新文案 |
|---|---|---|
| 风格 | 具体技术陈述 | 营销化口号 |
| 可验证性 | **高**（"视频帧不上传"技术上可验证、属实） | **低**（"告别隐私风险"是绝对化表述） |
| 合规风险 | 低 | **较高**——"完全/零风险/告别"类绝对化用词在隐私合规上易被认定为过度承诺。App 实际有网络通信（登录/会员/云同步/排行榜），说"告别隐私风险"可能被应用商店或监管质疑 |

### 这一项要怎么做

**先和用户讨论，再改。** 不要自行决定最终文案。

请向用户呈现以下选项，让其选择（可以用 AskUserQuestion）：

**选项 A：保留新文案**（接受合规风险）
- 用"完全本地化的视觉识别，告别隐私风险。"
- 适合：优先品牌冲击力，接受"告别风险"的绝对化表述

**选项 B：折中——保留新风格但去掉绝对化**（推荐）
- 例如："视觉识别在本地完成，画面不上传。"
- 保留"本地完成"的核心卖点，但用可验证的"画面不上传"替代"告别隐私风险"
- 适合：兼顾品牌调性和合规安全

**选项 C：恢复旧文案**
- "姿态识别在设备端完成 · 原始视频帧不上传"
- 最保守、最可验证

### 决定后

- 用户选定方案后，**中文 + 其余 7 语言统一用该方案**（和行动项 1 一起做）
- 更新测试 `"Chinese hero uses the approved headline"` 里 `privacy.short` 的断言值

---

## 已确认无问题的部分（供参考）

以下是本次审核确认通过的项，无需处理：

- ✅ 范围：只改 `website/`，零 App 代码（lib/test/workers/android/pubspec）触碰
- ✅ favicon.svg → app-icon.png：删除干净，index.html 三处引用全更新，无残留
- ✅ app-icon.png 来源：README 记录"复用 Android App 真实启动图标"，项目自有资产
- ✅ 商店按钮重设计：Google Play 四色标识 + Apple logo + 下载图标，有测试守护等高/平台标识
- ✅ 商店链接逻辑：未动，仍默认禁用/HTTPS-only
- ✅ 安全：无新外部引用/CDN/字体/追踪器/凭证
- ✅ 测试：39/39 全绿（新增 6 个测试覆盖 logo 一致性/hero 布局/商店按钮/中文文案）
- ✅ JS 语法：main.js / locales.js / store-links.js 全 OK

## 处理顺序建议

1. **先做行动项 2**：和用户讨论 `privacy.short` 最终文案（因为行动项 1 的翻译依赖这个决定）
2. **再做行动项 1**：拿到 privacy 最终文案后，一次性把 7 个语言的所有 key（含 privacy.short）同步到位
3. 跑测试确认全绿
4. 提交、推送、交给 main 侧复审
