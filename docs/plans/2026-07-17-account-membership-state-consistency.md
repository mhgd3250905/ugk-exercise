# Account And Membership State Consistency Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** 让首页、个人页和运动广场始终从同一个 `AccountController` 读取登录资料与会员状态，并在前台恢复、进入个人页和会员到期时及时更新。

**Architecture:** 保留 `main.dart` 中唯一的 `AccountController`，不引入新状态框架。Controller 负责刷新账号快照和会员到期通知；页面只触发刷新并监听 Controller。运动广场的 `canJoin`/`frozenTotalValue` 继续作为服务端业务数据，但生产 UI 的会员真假只由全局 Controller 决定。

**Tech Stack:** Flutter、Dart `ChangeNotifier`/`Timer`、现有 Widget/Controller 测试。

---

### Task 1: 统一账号与会员刷新

**Files:**
- Modify: `lib/control/account_controller.dart`
- Test: `test/account_controller_test.dart`

1. 先写失败测试：已登录时 `refresh()` 用 `/me` 同时更新用户和会员；登出后的迟到结果不能覆盖空状态；会员到期会通知监听者。
2. 运行：`flutter test test/account_controller_test.dart`，确认因 `refresh()` 和到期通知尚不存在而失败。
3. 最小实现：增加公开 `refresh()`；所有会员赋值统一经过 `_setMembership()`，在 `expiresAt` 安排一次 Timer 通知；清账号和 `dispose()` 时取消 Timer。
4. 重跑 Controller 测试并确认通过。

### Task 2: 页面触发全局刷新

**Files:**
- Modify: `lib/ui/pages/home_page.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Test: `test/home_page_test.dart`
- Test: `test/profile_page_test.dart`

1. 先写失败 Widget 测试：App 从后台回前台会调用全局刷新；进入个人页会刷新一次当前账号。
2. 运行两个测试文件中的定向用例，确认失败原因是刷新未触发。
3. 最小实现：`HomePage` 持有并释放 `AppLifecycleListener`；`ProfilePage.initState()` 触发同一个 `AccountController.refresh()`。Controller 自己拒绝未登录或繁忙时的重复刷新。
4. 重跑定向测试并确认通过。

### Task 3: 运动广场只展示全局会员状态

**Files:**
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Test: `test/leaderboard_page_test.dart`

1. 先写两条冲突测试：全局会员有效但旧快照 `canJoin=false` 时仍显示加入；全局非会员但快照 `canJoin=true` 时仍显示会员入口。
2. 运行定向测试，确认当前实现错误采用 `snapshot.canJoin`。
3. 最小实现：生产路径优先使用 `accountController.premium`；只有没有注入 Controller 的静态测试/预览才回退 `snapshot.canJoin`。刷新期间隐藏加入/付费操作。
4. 重跑运动广场与首页/个人页测试。

### Task 4: 文档与全量验证

**Files:**
- Modify: `docs/modules/membership.md`
- Modify: `docs/design/app-ui-v1.md`

1. 记录全局状态源、前台/个人页刷新和运动广场展示规则，不改远端合同。
2. 运行 `dart format`、`flutter analyze`、`flutter test`、`git diff --check`。
3. 保持回放基线 step0=5、v3=5、v4=3；显式 stage 本次文件并提交，不 push。
