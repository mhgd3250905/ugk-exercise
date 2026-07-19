# 实时训练页质感优化 Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `test-driven-development` to implement this plan task-by-task.

**Goal:** 将实时训练页升级为“相机舞台 + 单一教练状态栏 + 紧凑计数控制台”，让当前次数成为唯一视觉锚点，并移除固定目标与热量伪数据。

**Architecture:** 仅调整 `WorkoutPage` 的展示层和 Widget 测试。页面继续只读取 `WorkoutController`；相机预览、姿态剪影、窄距门控、计数状态机和停止保存生命周期保持原样。新增 UI helper 仍就近放在 `workout_page.dart`，不引入依赖或新数据模型。

**Tech Stack:** Flutter Material 3、现有 AppTheme / ARB l10n、flutter_test。

---

### Task 1: 锁定单一状态与真实数据表达

**Files:**

- Modify: `test/workout_page_test.dart`
- Modify: `lib/ui/pages/workout_page.dart`

**Step 1: Write the failing test**

新增 Widget 测试，断言训练中页面：

```dart
expect(find.byKey(const ValueKey('workout-coach-bar')), findsOneWidget);
expect(find.byKey(const ValueKey('workout-top-status-chip')), findsNothing);
expect(find.text('今日目标'), findsNothing);
expect(find.text('消耗'), findsNothing);
expect(find.text('100 个'), findsNothing);
expect(find.text('32 千卡'), findsNothing);
```

**Step 2: Run the focused test to verify it fails**

```powershell
flutter test test/workout_page_test.dart --plain-name "uses one coach bar and omits fixed workout statistics"
```

Expected: FAIL，因为旧页面仍有两个状态胶囊和固定统计。

**Step 3: Write the minimal implementation**

- 移除相机顶部 `_WorkoutChip`；顶部只保留关闭和相机切换控制。
- 用一个位于相机与控制台交界处的 `_WorkoutCoachBar` 展示完整 `WorkoutStatus` 文案。
- 从 `_WorkoutCountPanel` 删除固定“目标 100”“消耗 32 kcal”两侧统计；进度环仅服务当前次数的视觉反馈，不宣称目标达成。

**Step 4: Run the focused test to verify it passes**

Run the same command; expected PASS.

### Task 2: 建立主题一致的相机舞台和计数控制台

**Files:**

- Modify: `test/workout_page_test.dart`
- Modify: `lib/ui/pages/workout_page.dart`

**Step 1: Write the failing tests**

覆盖以下可观察行为：

```dart
expect(
  tester.getRect(find.byKey(const ValueKey('workout-coach-bar'))).bottom,
  lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('workout-count-panel'))).top),
);
expect(find.byKey(const ValueKey('workout-camera-stage')), findsOneWidget);
expect(find.byKey(const ValueKey('workout-count-panel')), findsOneWidget);
```

并分别以 `appTheme(brightness: Brightness.light)` 与深色主题泵送页面，确认相机菜单和控制台采用主题 surface/onSurface，而不是硬编码纯白/深墨色。

**Step 2: Run focused tests to verify they fail**

```powershell
flutter test test/workout_page_test.dart --plain-name "uses a theme-aware camera stage and count console"
```

Expected: FAIL，因为旧页没有舞台/教练栏标识，且菜单硬编码白色。

**Step 3: Write the minimal implementation**

- 为相机区域添加 `workout-camera-stage` key、底部渐变可读性层，中央有效观察区保持透明，不遮挡姿态剪影。
- 将返回、相机切换改为 48dp 主题感知的半透明圆形控制；保留既有动作和 `PopupMenuButton` 逻辑。
- 使用浅色暖白/鼠尾草抬升表面、深色森林表面构建圆角计数控制台；不加装饰性粗边框。
- 调整控制台高度为基于可用高度的自适应范围，替代固定最小 330dp，保留底部安全区和固定结束按钮。
- 结束按钮继续使用 `coral`，行为、文案和保存失败重试逻辑不变。

**Step 4: Run focused tests to verify they pass**

Run the same focused command; expected PASS.

### Task 3: 守住小屏、多语言与无障碍

**Files:**

- Modify: `test/workout_page_test.dart`
- Modify: `lib/ui/pages/workout_page.dart`

**Step 1: Write failing tests**

- 在 `320×640`、底部安全区、英文窄距长提示下：无 overflow，教练栏不覆盖控制台。
- 关闭、相机选择与结束训练的最小触控尺寸为 48dp；关闭和计数区域有明确 Semantics 标签。
- 训练数字与单位使用合并语义，例如“当前 7 个 / 7 reps”。

**Step 2: Run focused tests to verify they fail**

```powershell
flutter test test/workout_page_test.dart --plain-name "keeps the live workout controls accessible on a compact English viewport"
```

Expected: FAIL，因为旧页面没有对应语义和紧凑视口断言。

**Step 3: Write minimal implementation**

- 为视觉状态和读屏状态分别提供本地化短标签；不新增 domain/product 文案。
- 使用 `SafeArea`、`ConstrainedBox`、`Flexible` 与文字截断保证长文案不溢出。
- 控制台与相机之间保留稳定间距；不得把不透明提示条放到相机中央。

**Step 4: Run focused tests to verify they pass**

Run the same focused command; expected PASS.

### Task 4: 更新维护规则并做全量验证

**Files:**

- Modify: `docs/design/app-ui-v1.md`
- Modify: `lib/ui/pages/workout_page.dart`
- Modify: `test/workout_page_test.dart`

**Step 1: Update the design document**

将 §5.2 更新为单一教练状态栏、无伪实时目标/热量、主题感知计数控制台与相机中央观察区不被遮挡的维护规则。

**Step 2: Run verification**

```powershell
flutter analyze
flutter test
git diff --check
```

Expected: 全部通过，回放基线维持 5/5/3。

**Step 3: Do a real-device smoke check**

按已有带本机构建配置的安全调试流程进入训练页，检查浅/深色、状态变化、相机预览/姿态剪影、结束训练和系统安全区。不得清除 App 数据，也不得输出设备日志或配置值。

**Step 4: Prepare reviewable handoff**

仅在验证完成后显式暂存本任务文件、创建本地提交；不 push、merge、部署或改远端。
