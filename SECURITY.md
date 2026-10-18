# Security Policy

## Supported versions

项目目前处于预发布阶段，仅最新版 `main` 和最新 GitHub Release 获得安全更新。

| Version | Supported |
|---|---|
| 0.1.x / main | Yes |
| older snapshots | No |

## Reporting a vulnerability

请不要在公开 Issue 中报告以下内容：

- API Key、Cookie、Token 或凭据；
- 可复现的凭据窃取方法；
- DSH 审批或 Sandbox 绕过；
- 任意命令执行或不安全进程启动；
- 安装包供应链或更新劫持问题。

请使用 GitHub 仓库的 **Security → Report a vulnerability** 私密报告功能。仓库创建后，维护者应启用 GitHub Private Vulnerability Reporting。

报告请包含：

1. 受影响版本或 commit；
2. 环境与 DSH 版本；
3. 最小复现步骤；
4. 实际与预期行为；
5. 影响分析；
6. 可行的缓解建议。

请勿附带真实凭据。维护者目标是在 7 天内确认报告，并在验证后协调修复和披露时间。

## Security boundaries

- DeepSeek API Key 存放在 Windows Credential Manager；保护边界是当前 Windows 用户，而不是独立硬件保险库。
- WebView 只能提交新 Key，不能读回已保存 Key。
- 余额只访问 `https://api.deepseek.com/user/balance`。
- DSH 的审批、权限和 Sandbox 始终具有权威性。
- Companion 使用 ACP stdio，不应开放非 loopback 控制端口。

完整设计见 [`docs/security.md`](docs/security.md)。
