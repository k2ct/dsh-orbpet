# DSH Desktop Companion

[![CI](https://github.com/k2ct/dsh-orbpet/actions/workflows/ci.yml/badge.svg)](https://github.com/k2ct/dsh-orbpet/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D6)](https://www.microsoft.com/windows)

一个由 DeepSeek Harness（DSH）Plugin 自动托管的 Windows 原生桌面伴侣，把 **余额悬浮球、像素桌宠和 DSH 对话** 合并到同一个 Tauri 应用中。它通过 ACP stdio 与 DSH 通信，不要求打开 DSH 网页端。

> 项目处于 `0.1.0` 预发布阶段。核心链路已经可用并有自动化测试，但安装程序、视觉资产和不同机器上的兼容性仍需继续验证。

## 功能

- 桌宠、余额球、聊天三种显示模式
- 透明、置顶、无边框、跳过任务栏的原生窗口
- 托盘显示、隐藏和退出
- 点击穿透与恢复交互
- DSH Plugin 自动启动和关闭 Companion
- ACP v1 NDJSON 长期连接和 Session 复用
- ACP 流式文本事件、取消回答和 Session 恢复
- DeepSeek 官方 `/user/balance` 余额查询
- Windows Credential Manager 安全保存 DeepSeek API Key
- 单实例、生命周期和孤儿进程自动化测试

## 架构

```text
DSH Desktop / CLI runtime
        │
        │ Cordis Plugin lifecycle
        ▼
dsh-desktop-companion-plugin
        │
        │ starts / stops
        ▼
DSH Companion (Tauri 2)
   ├─ transparent pet / orb / chat UI
   ├─ Windows Credential Manager
   ├─ DeepSeek official balance API
   └─ dsh --profile acp (stdio, ACP v1)
```

Companion 不依赖 DSH GUI 的随机 localhost 端口或私有 Electron IPC，也不会绕过 DSH 的审批和 Sandbox。

## 当前状态

| 模块 | 状态 |
|---|---|
| Tauri 原生窗口、托盘、单实例 | 已实现 |
| 桌宠、余额球、聊天 UI | 已实现基础版本 |
| Plugin 自动托管 | 已在隔离 profile 验证 |
| ACP 长期进程、流式事件、取消 | 已实现 |
| ACP Session 持久化与恢复 | 已实现 |
| Windows Credential Manager | 已实现并完成写入/读取/删除探针 |
| DeepSeek 官方余额 | 已实现；真实余额需要用户自己的 API Key |
| Release EXE / NSIS | 可由发布脚本和 CI 构建 |
| 多 DPI、多显示器、动画资产 | 待完善 |

详细证据见 [`docs/m0-status.md`](docs/m0-status.md)。

## 系统要求

- Windows 10 或 Windows 11（x64）
- Microsoft Edge WebView2 Runtime
- DeepSeek Harness `>=0.2.1-rc.2 <0.3.0`
- 开发环境：
  - Node.js 20+
  - pnpm 11
  - Rust stable（MSVC target）
  - Visual Studio 2022 Build Tools，包含 Desktop development with C++

## 快速开始：开发

```powershell
git clone https://github.com/k2ct/dsh-orbpet.git
cd dsh-orbpet
pnpm install --frozen-lockfile
pnpm check
pnpm test
pnpm dev
```

`pnpm dev` 启动的是 Tauri 开发窗口，不会主动打开 DSH Web profile。Companion 与 DSH 的对话通信使用：

```text
dsh --profile acp
```

### 构建 Debug 版本

```powershell
pnpm --filter @dsh-companion/app tauri build --debug --no-bundle
```

### 构建 Release 产物

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-release.ps1 -Clean
```

产物会生成到被 Git 忽略的 `release/` 目录，包括：

- Companion Release EXE
- DSH Plugin 分发目录和压缩包
- NSIS 安装程序（构建环境支持时）
- SHA-256 校验文件

## 安装 DSH Plugin

正式 Release 的 Plugin 包内应包含：

```text
dsh-desktop-companion-plugin/
├─ bin/dsh-companion.exe
├─ lib/index.js
├─ package.json
├─ cordis.patch.yml
├─ README.md
├─ LICENSE
└─ THIRD_PARTY_NOTICES.md
```

下载并解压 Release 后，在 PowerShell 中运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-plugin.ps1 -PackagePath .\dsh-desktop-companion-plugin
```

卸载：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/uninstall-plugin.ps1
```

安装脚本默认目标是名为 `companion` 的非保留 DSH profile。除非你明确了解 DSH Desktop profile 的管理方式，否则不要通过 CLI 修改保留的 `desktop` profile。

## 配置 DeepSeek 余额

在 Companion 中点击“设置 Key”，输入 DeepSeek 官方 API Key。Key 会保存到 Windows Credential Manager：

- 不写入 `.env` 或配置文件
- 不返回给 WebView
- 不进入日志
- 不随 Git 或 Release 包分发

余额只请求官方地址：

```text
GET https://api.deepseek.com/user/balance
```

更多说明见 [`docs/security.md`](docs/security.md)。

## 验证命令

```powershell
pnpm check
pnpm test
powershell -ExecutionPolicy Bypass -File scripts/check-environment.ps1
powershell -ExecutionPolicy Bypass -File scripts/probe-dsh-acp.ps1
powershell -ExecutionPolicy Bypass -File scripts/native-self-test.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-native.ps1 -Iterations 20
```

这些探针不要求启动 DSH Web profile。

## 仓库结构

```text
apps/companion/          Tauri 桌面应用
packages/protocol/       Plugin / Companion 稳定消息契约
packages/pet-state/      DSH 状态到桌宠状态的归一化逻辑
plugins/dsh-companion/   DSH Cordis Plugin
scripts/                 构建、安装和测试脚本
docs/                    架构、安全和验证证据
.github/                 CI、Issue 和 PR 模板
```

## 安全原则

- 不读取浏览器 Cookie，不使用 DeepSeek 私有 Web 接口
- API Key 仅由 Rust 后端和 Windows Credential Manager 处理
- Companion 不绕过 DSH 审批或 Sandbox
- ACP 使用 stdio，不对外监听控制端口
- 日志不得包含 Bearer Token、Cookie 或凭据

发现安全问题请阅读 [`SECURITY.md`](SECURITY.md)，不要在公开 Issue 中提交秘密或漏洞利用细节。

## 开源与贡献

- License：MIT，见 [`LICENSE`](LICENSE)
- 贡献指南：[`CONTRIBUTING.md`](CONTRIBUTING.md)
- 行为准则：[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- 变更记录：[`CHANGELOG.md`](CHANGELOG.md)
- 第三方说明：[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)

项目借鉴了若干开源桌宠和 DSH 集成项目的架构思路，但当前没有复制其源代码或美术资产。精确边界记录在第三方说明中。

## 发布到 GitHub

1. 在 GitHub 创建空仓库（不要初始化 README、`.gitignore` 或 License）。
2. 将占位链接替换为实际用户名或组织名：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/init-github.ps1 -Owner <你的GitHub用户名> -Repository dsh-orbpet -SetRemote
```

3. 运行发布预检：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/preflight-release.ps1 -SkipReleaseBuild
```

4. 首次推送：

```powershell
git push -u origin main
```

5. 创建版本标签触发 Release 工作流：

```powershell
git tag v0.1.0
git push origin v0.1.0
```

CI 会执行 TypeScript/Vite 检查、Node 测试、Rust 格式和测试；标签发布会构建 EXE、NSIS 安装程序、Plugin 包与 `SHA256SUMS.txt`。

发布后建议在仓库设置中启用：

- Branch protection（要求 CI 通过）
- Secret scanning 与 push protection
- Private vulnerability reporting
- Dependabot alerts
