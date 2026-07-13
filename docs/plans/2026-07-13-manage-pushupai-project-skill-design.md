# PushupAI 项目管理 Skill 设计

日期：2026-07-13

## 目标

创建可被 Codex 自动发现的 `manage-pushupai-project` Skill，帮助接手者按任务类型读取正确文档、保护秘密与用户文件、执行必要测试，并在远程写入前确认授权。

## 结构

- 正本：`.agents/skills/manage-pushupai-project/`，随 App 仓库版本管理。
- 本机入口：`%USERPROFILE%\.codex\skills\manage-pushupai-project`，指向正本，避免双份内容漂移。
- `SKILL.md`：入口流程、开发纪律、测试与交付要求。
- `references/task-routing.md`：开发、UI、算法、语音、会员、Worker/D1、打包、上架和交接的文档路由。
- `references/authority-and-ledger.md`：远程操作授权及公开/私密台账边界。
- `scripts/preflight.ps1`：只读检查 Git、关键文档和本机 info 仓库保护状态。

## 原则

1. 复用现有权威文档，不复制易过期的版本号、控制台状态或密钥位置。
2. Skill 和 App 仓库不保存 Secret、Token、密码、私钥、个人邮箱或构建产物。
3. 远程部署、D1 修改、密钥轮换、Google Play 操作、购买、push、删除数据均需用户明确授权。
4. 预检脚本只读取和报告，不修改分支、文件、remote 或外部系统。
5. 新逻辑遵守 TDD、架构分层、最小修改和按风险分层验证。

## 验收

- `quick_validate.py` 验证 Skill 结构通过。
- `preflight.ps1` 在 App 仓库运行成功，能识别受保护未跟踪文件和 info 仓库无 remote。
- 敏感模式扫描通过。
- 本机 Skill 入口解析到项目正本。
- `AGENTS.md` 明确要求 PushupAI 任务优先使用该 Skill。
