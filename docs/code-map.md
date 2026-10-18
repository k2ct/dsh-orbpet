# 代码地图

本文按目录解释仓库中每个文件的作用，适合第一次阅读本项目、准备继续开发的读者。

- 仓库：`k2ct/dsh-orbpet`
- 版本：`0.1.0`
- 平台：Windows 10/11 x64
- 技术栈：Tauri 2 + TypeScript + Rust

---

## 1. 先理解三个进程

```text
┌─────────────────────────────┐
│ DSH Desktop / DSH CLI       │
│  Cordis 插件宿主             │
└──────────────┬──────────────┘
               │ 启动 / 关闭
               ▼
┌─────────────────────────────┐
│ dsh-desktop-companion-plugin│
│  plugins/dsh-companion      │
└──────────────┬──────────────┘
               │ spawn
               ▼
┌─────────────────────────────┐
│ DSH Companion (Tauri 2)     │
│  ├─ WebView UI (TS/CSS)      │
│  ├─ Rust 后端                │
│  │   ├─ 托盘 / 窗口          │
│  │   ├─ Credential Manager   │
│  │   └─ DeepSeek 余额        │
│  └─ 子进程 dsh --profile acp │
└─────────────────────────────┘
```

WebView 只负责显示和输入，**不接触 API Key**。Rust 负责凭据、网络和 ACP。

---

## 2. 仓库总览

```text
DSHCompanion/
├─ .github/                 GitHub Actions 与模板
├─ apps/companion/          Tauri 桌面应用
│  ├─ src/                  前端 TypeScript / CSS
│  ├─ test/                 前端测试
│  └─ src-tauri/            Rust 后端与 Tauri 配置
├─ packages/
│  ├─ protocol/             共享消息契约
│  └─ pet-state/            状态归一化
├─ plugins/dsh-companion/   DSH Cordis 插件
├─ scripts/                 构建、安装、测试脚本
├─ docs/                    架构、安全、ACP、代码地图
├─ package.json             workspace 根配置
├─ pnpm-workspace.yaml      子包声明
└─ pnpm-lock.yaml           依赖锁定
```

---

## 3. 根目录文件

| 文件 | 作用 |
|---|---|
| [README.md](../README.md) | 项目首页：功能、架构、状态、安装、构建、发布 |
| [LICENSE](../LICENSE) | MIT 许可证 |
| [CHANGELOG.md](../CHANGELOG.md) | 版本变更记录 |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | 贡献流程、提交规范、PR 检查项 |
| [SECURITY.md](../SECURITY.md) | 漏洞报告方式与安全边界 |
| [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) | 社区行为准则 |
| [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) | 依赖许可证与参考项目 |
| [package.json](../package.json) | pnpm workspace 根配置与统一脚本 |
| [pnpm-workspace.yaml](../pnpm-workspace.yaml) | 声明 `apps/*`、`packages/*`、`plugins/*` 为子包 |
| [pnpm-lock.yaml](../pnpm-lock.yaml) | 锁定所有 JavaScript 依赖版本 |
| [.gitignore](../.gitignore) | 排除依赖、构建产物、`release/`、密钥 |
| [.gitattributes](../.gitattributes) | 统一换行符、标记二进制 |
| [.editorconfig](../.editorconfig) | 编辑器缩进与编码规则 |
| [.env.example](../.env.example) | 环境变量示例（空值） |

根 `package.json` 的脚本：

```json
"dev":   "pnpm --filter @dsh-companion/app tauri dev",
"build": "pnpm --filter @dsh-companion/app tauri build",
"check": "pnpm -r check",
"test":  "pnpm -r test"
```

---

## 4. `.github/`

| 文件 | 作用 |
|---|---|
| [workflows/ci.yml](../.github/workflows/ci.yml) | 推 `main` 或 PR 时运行 TypeScript、Node、Rust 检查 |
| [workflows/release.yml](../.github/workflows/release.yml) | 推送 `v*` 标签时构建 EXE/NSIS/ZIP 并创建 Release |
| [dependabot.yml](../.github/dependabot.yml) | 每周检查 npm、cargo、GitHub Actions 更新 |
| [ISSUE_TEMPLATE/bug_report.yml](../.github/ISSUE_TEMPLATE/bug_report.yml) | Bug Issue 表单 |
| [ISSUE_TEMPLATE/feature_request.yml](../.github/ISSUE_TEMPLATE/feature_request.yml) | 功能建议表单 |
| [ISSUE_TEMPLATE/config.yml](../.github/ISSUE_TEMPLATE/config.yml) | Issue 页面链接到私密安全报告 |
| [PULL_REQUEST_TEMPLATE.md](../.github/PULL_REQUEST_TEMPLATE.md) | PR 自检清单 |

`ci.yml` 的核心步骤：

```yaml
pnpm install --frozen-lockfile
pnpm check
pnpm test
cargo fmt -- --check
cargo test --locked
cargo check --release --locked
```

`release.yml` 的核心步骤：

```yaml
pnpm/action-setup
setup-node
rust-toolchain
pnpm check / test
cargo test
./scripts/build-release.ps1 -Clean
upload-artifact
softprops/action-gh-release
```

---

## 5. `apps/companion/` 前端

| 文件 | 作用 |
|---|---|
| [index.html](../apps/companion/index.html) | Vite 入口，提供 `#app` 根节点，加载 `src/main.ts` |
| [package.json](../apps/companion/package.json) | 应用依赖与脚本 |
| [tsconfig.json](../apps/companion/tsconfig.json) | TypeScript 配置：ES2022、Bundler 解析、`noEmit` |
| [vite.config.ts](../apps/companion/vite.config.ts) | Vite 端口固定 1420 |
| [src/main.ts](../apps/companion/src/main.ts) | UI 主逻辑：模式、聊天、余额、凭据、渲染 |
| [src/styles.css](../apps/companion/src/styles.css) | 透明窗口、像素桌宠、余额球、聊天样式 |
| [src/dsh-adapter.ts](../apps/companion/src/dsh-adapter.ts) | 前端与 Rust 的桥梁：命令调用与流式事件 |
| [test/dsh-adapter.test.ts](../apps/companion/test/dsh-adapter.test.ts) | 适配器单元测试 |

### 5.1 `main.ts` 的状态

```ts
let displayMode: "pet" | "orb" | "chat" | ...
let dshState: "offline" | "idle" | "thinking" | ...
let messages: ChatMessage[]
let balance: BalanceResponse
let credentialConfigured: boolean
let busy: boolean
let clickThrough: boolean
```

### 5.2 `main.ts` 的主要函数

| 函数 | 作用 |
|---|---|
| `render()` | 根据状态重建整个 DOM |
| `connect()` | 调用 `acp_handshake`，更新连接状态 |
| `submitPrompt()` | 发送消息并消费流式事件 |
| `cancelPrompt()` | 调用 `acp_cancel` |
| `refreshBalance()` | 调用 `get_deepseek_balance` |
| `configureCredential()` | 保存 API Key |
| `toggleClickThrough()` | 切换点击穿透 |

### 5.3 `dsh-adapter.ts`

```ts
connect()   → invoke("acp_handshake")
prompt()    → listen("acp-stream-<uuid>") + invoke("acp_prompt_stream")
cancel()    → invoke("acp_cancel")
close()     → invoke("acp_disconnect")
```

它把 Rust 发来的事件：

```text
status / textDelta / completed / error
```

转换成前端事件：

```text
status / text-delta / completed / error
```

---

## 6. `apps/companion/src-tauri/` 配置

| 文件 | 作用 |
|---|---|
| [tauri.conf.json](../apps/companion/src-tauri/tauri.conf.json) | 产品名、窗口参数、CSP、NSIS 打包、图标 |
| [Cargo.toml](../apps/companion/src-tauri/Cargo.toml) | Rust 包名、依赖、`default-run` |
| [Cargo.lock](../apps/companion/src-tauri/Cargo.lock) | 锁定 Rust 依赖 |
| [build.rs](../apps/companion/src-tauri/build.rs) | 调用 `tauri_build::build()` |
| [capabilities/default.json](../apps/companion/src-tauri/capabilities/default.json) | 前端可用的窗口权限 |
| [rustfmt.toml](../apps/companion/src-tauri/rustfmt.toml) | Rust 格式化配置 |
| [icons/icon.png](../apps/companion/src-tauri/icons/icon.png) | 应用图标 |
| [icons/icon.ico](../apps/companion/src-tauri/icons/icon.ico) | Windows 图标 |

窗口关键参数：

```json
"transparent": true,
"decorations": false,
"alwaysOnTop": true,
"skipTaskbar": true,
"resizable": false,
"shadow": false
```

---

## 7. `apps/companion/src-tauri/src/` Rust

| 文件 | 作用 |
|---|---|
| [main.rs](../apps/companion/src-tauri/src/main.rs) | 只调用 `dsh_companion_lib::run()` |
| [lib.rs](../apps/companion/src-tauri/src/lib.rs) | 应用入口：单实例、托盘、自检、命令注册 |
| [dsh.rs](../apps/companion/src-tauri/src/dsh.rs) | 定位 `dsh.cmd`、版本探测、ACP 命令封装 |
| [acp.rs](../apps/companion/src-tauri/src/acp.rs) | ACP 客户端、会话恢复、流式事件、取消 |
| [balance.rs](../apps/companion/src-tauri/src/balance.rs) | Credential Manager 与 DeepSeek 余额 |

### 7.1 注册的 Tauri 命令

```text
set_click_through
probe_dsh_environment
acp_handshake
acp_prompt_stream
acp_cancel
acp_disconnect
deepseek_credential_status
save_deepseek_api_key
delete_deepseek_api_key
get_deepseek_balance
```

### 7.2 `acp.rs` 结构

```rust
AcpClient       // 子进程、stdin/stdout、会话 ID
AcpManager      // 全局单例，负责连接、失效、断开
AcpStreamEvent  // status / textDelta / completed / error
```

### 7.3 `balance.rs` 结构

```rust
BalanceResponse   // is_available + balance_infos
CredentialStatus  // { configured, storage }
fetch_balance()   // GET https://api.deepseek.com/user/balance
```

### 7.4 探针程序

| 文件 | 验证内容 |
|---|---|
| [bin/acp_probe.rs](../apps/companion/src-tauri/src/bin/acp_probe.rs) | initialize + session/new |
| [bin/acp_persistent_probe.rs](../apps/companion/src-tauri/src/bin/acp_persistent_probe.rs) | 同一进程内会话复用 |
| [bin/acp_resume_probe.rs](../apps/companion/src-tauri/src/bin/acp_resume_probe.rs) | 跨进程 `session/resume` |
| [bin/credential_probe.rs](../apps/companion/src-tauri/src/bin/credential_probe.rs) | Credential Manager 写入/读取/删除 |

运行方式：

```powershell
cargo run --manifest-path apps/companion/src-tauri/Cargo.toml --bin acp_persistent_probe
cargo run --manifest-path apps/companion/src-tauri/Cargo.toml --bin acp_resume_probe
cargo run --manifest-path apps/companion/src-tauri/Cargo.toml --bin credential_probe
```

---

## 8. `packages/protocol/`

| 文件 | 作用 |
|---|---|
| [src/index.ts](../packages/protocol/src/index.ts) | 插件与 Companion 的稳定消息契约 |
| [package.json](../packages/protocol/package.json) | 包名 `@dsh-companion/protocol` |
| [tsconfig.json](../packages/protocol/tsconfig.json) | 编译配置 |

核心类型：

```ts
PROTOCOL_VERSION = 1

DisplayMode
  // pet / orb / chat / approval / offline / hidden

NormalizedDshState
  // offline / idle / thinking / working /
  // waiting_approval / error / completed

PluginToCompanion
  // hello / dsh-state / show / shutdown

CompanionToPlugin
  // ready / heartbeat / diagnostic / request-open-dsh

DshEvent
  // status / text-delta / completed / error
```

---

## 9. `packages/pet-state/`

| 文件 | 作用 |
|---|---|
| [src/index.ts](../packages/pet-state/src/index.ts) | 把 DSH 原始信号转换成稳定视觉状态 |
| [test/reducer.test.ts](../packages/pet-state/test/reducer.test.ts) | 状态映射测试 |
| [package.json](../packages/pet-state/package.json) | 包配置 |
| [tsconfig.json](../packages/pet-state/tsconfig.json) | 编译配置 |

映射关系：

```text
connected            → idle
disconnected         → offline
assistant-thinking   → thinking
tool-started         → working
approval-required    → waiting_approval
turn-completed       → completed
failure              → error
```

---

## 10. `plugins/dsh-companion/`

| 文件 | 作用 |
|---|---|
| [package.json](../plugins/dsh-companion/package.json) | 包名、入口、`engines.dsh`、bundle 声明、发布白名单 |
| [cordis.patch.yml](../plugins/dsh-companion/cordis.patch.yml) | 向 DSH Cordis 配置插入插件条目 |
| [lib/index.js](../plugins/dsh-companion/lib/index.js) | 启动/停止 Companion，解析可执行文件路径 |
| [test/supervisor.test.js](../plugins/dsh-companion/test/supervisor.test.js) | 进程监督测试 |
| [README.md](../plugins/dsh-companion/README.md) | 插件安装与配置说明 |

bundle 声明：

```json
"dsh": {
  "bundle": {
    "patch": "./cordis.patch.yml"
  }
}
```

插入配置：

```yaml
- insert:
    - id: dsh-desktop-companion
      name: dsh-desktop-companion-plugin
```

默认可执行文件路径：

```text
plugins/dsh-companion/bin/dsh-companion.exe
```

发布包会把这个 EXE 一起打包。

---

## 11. `scripts/`

| 脚本 | 作用 |
|---|---|
| [check-environment.ps1](../scripts/check-environment.ps1) | 检查 Node、pnpm、Rust、Git、DSH |
| [probe-dsh-acp.ps1](../scripts/probe-dsh-acp.ps1) | 启动 `dsh --profile acp`，关闭 stdin，验证退出 |
| [probe-dsh-headless.ps1](../scripts/probe-dsh-headless.ps1) | 调用 `dsh headless` 单轮对话 |
| [native-self-test.ps1](../scripts/native-self-test.ps1) | 验证托盘初始化与点击穿透 API |
| [smoke-native.ps1](../scripts/smoke-native.ps1) | 多轮启动、单实例、退出、残留进程检查 |
| [build-release.ps1](../scripts/build-release.ps1) | 生成 EXE、NSIS、插件 ZIP、SHA256SUMS |
| [install-plugin.ps1](../scripts/install-plugin.ps1) | 安装插件到非保留 DSH profile |
| [uninstall-plugin.ps1](../scripts/uninstall-plugin.ps1) | 从 DSH profile 移除插件 |
| [preflight-release.ps1](../scripts/preflight-release.ps1) | 发布前自检 |
| [init-github.ps1](../scripts/init-github.ps1) | 替换 GitHub 占位链接并设置 remote |

发布产物：

```text
release/
├─ dsh-companion.exe
├─ dsh-desktop-companion-plugin-windows-x64.zip
├─ DSH.Companion_0.1.0_x64-setup.exe
└─ SHA256SUMS.txt
```

---

## 12. `docs/`

| 文件 | 作用 |
|---|---|
| [architecture.md](architecture.md) | 进程模型与稳定边界 |
| [security.md](security.md) | 信任边界、凭据策略、残留风险 |
| [acp.md](acp.md) | ACP v1 协议、握手、Prompt、取消、恢复 |
| [m0-status.md](m0-status.md) | 各阶段验证证据与未完成项 |
| [code-map.md](code-map.md) | 本文，逐文件说明 |
| [startup-flow.md](startup-flow.md) | 从进程启动到显示桌宠的完整调用链 |

`docs/environment-report.json` 是 [check-environment.ps1](../scripts/check-environment.ps1) 生成的本机报告，已被忽略，不应提交。

---

## 13. 生成目录（不在 Git 中）

| 目录 | 来源 |
|---|---|
| `node_modules/` | pnpm 安装的依赖 |
| `apps/companion/dist/` | Vite 前端构建产物 |
| `apps/companion/src-tauri/target/` | Rust 编译产物 |
| `apps/companion/src-tauri/gen/` | Tauri 生成的 schema |
| `release/` | `build-release.ps1` 生成的安装包 |
| `.tool-shims/` | 本机 pnpm 启动脚本 |
| `.tooling/` | 临时探针脚本 |

这些目录都不应提交。

---

## 14. 推荐阅读顺序

1. [README.md](../README.md)
2. [architecture.md](architecture.md)
3. [protocol/src/index.ts](../packages/protocol/src/index.ts)
4. [pet-state/src/index.ts](../packages/pet-state/src/index.ts)
5. [dsh-adapter.ts](../apps/companion/src/dsh-adapter.ts)
6. [main.ts](../apps/companion/src/main.ts)
7. [lib.rs](../apps/companion/src-tauri/src/lib.rs)
8. [dsh.rs](../apps/companion/src-tauri/src/dsh.rs)
9. [acp.rs](../apps/companion/src-tauri/src/acp.rs)
10. [balance.rs](../apps/companion/src-tauri/src/balance.rs)
11. [plugins/dsh-companion/lib/index.js](../plugins/dsh-companion/lib/index.js)
12. [build-release.ps1](../scripts/build-release.ps1)

---

## 15. 修改指南

| 想改的内容 | 文件 |
|---|---|
| 桌宠外观 | [styles.css](../apps/companion/src/styles.css) |
| 聊天交互 | [main.ts](../apps/companion/src/main.ts) |
| 前端调用 Rust 的接口 | [dsh-adapter.ts](../apps/companion/src/dsh-adapter.ts) |
| 窗口大小、透明、置顶 | [tauri.conf.json](../apps/companion/src-tauri/tauri.conf.json) |
| 托盘菜单 | [lib.rs](../apps/companion/src-tauri/src/lib.rs) |
| ACP 协议行为 | [acp.rs](../apps/companion/src-tauri/src/acp.rs) |
| 余额与 API Key | [balance.rs](../apps/companion/src-tauri/src/balance.rs) |
| 插件启动参数 | [plugins/dsh-companion/lib/index.js](../plugins/dsh-companion/lib/index.js) |
| 安装包内容 | [build-release.ps1](../scripts/build-release.ps1) |
| CI / 发布流程 | [.github/workflows](../.github/workflows) |

---

## 16. 常用命令

```powershell
# 安装依赖
pnpm install --frozen-lockfile

# 类型检查 / 前端构建 / 全部测试
pnpm check
pnpm test

# 开发模式（Tauri 窗口 + Vite）
pnpm dev

# 构建 Debug EXE
pnpm --filter @dsh-companion/app tauri build --debug --no-bundle

# 构建 Release 安装包
powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 -Clean

# 原生自检
powershell -ExecutionPolicy Bypass -File scripts\native-self-test.ps1

# 生命周期测试
powershell -ExecutionPolicy Bypass -File scripts\smoke-native.ps1 -Iterations 5
```
