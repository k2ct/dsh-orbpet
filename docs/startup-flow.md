# 启动流程：从 EXE 到桌宠

本文按真实执行顺序说明：Windows 启动 `dsh-companion.exe` 之后，`main.rs → lib.rs → index.html → main.ts` 如何一步步显示出桌宠。

- 相关文件：
  - [main.rs](../apps/companion/src-tauri/src/main.rs)
  - [lib.rs](../apps/companion/src-tauri/src/lib.rs)
  - [tauri.conf.json](../apps/companion/src-tauri/tauri.conf.json)
  - [index.html](../apps/companion/index.html)
  - [main.ts](../apps/companion/src/main.ts)
  - [styles.css](../apps/companion/src/styles.css)

---

## 0. 总览

```text
[Windows]
  dsh-companion.exe
        │
        ▼
[main.rs]
  dsh_companion_lib::run()
        │
        ▼
[lib.rs]
  Builder::default()
    ├─ manage(AcpManager)          // 只创建，不连接
    ├─ plugin(single_instance)     // 防重复启动
    ├─ setup(...)                  // 托盘、测试模式
    ├─ invoke_handler(...)         // 注册命令
    └─ run(generate_context!())    // 读配置、建窗口
                │
                ▼
[WebView2]
  加载 index.html
        │
        ▼
[main.ts]
  初始化状态
        │
        ├─ render()                // 立刻画出桌宠
        │
        └─ connect()
              │ invoke("acp_handshake")
              ▼
        [Rust dsh.rs]
              │
              ▼
        [Rust acp.rs]
              │ 启动 dsh --profile acp
              │ initialize + session/resume|new
              ▼
        返回 handshake
              │
              ▼
        dshState = "idle"
        render()                   // 状态点变绿
```

---

## 1. 阶段 0：进程启动

[main.rs](../apps/companion/src-tauri/src/main.rs) 只有 3 行：

```rust
fn main() {
    dsh_companion_lib::run();
}
```

为什么这么薄？

- Tauri 推荐把逻辑放在 `lib.rs`，`main.rs` 只做入口；
- 同一套库未来可以复用到移动端或其他宿主；
- Cargo 中 `[lib] name = "dsh_companion_lib"` 就是对应关系。

---

## 2. 阶段 1：Builder 组装应用

进入 [lib.rs](../apps/companion/src-tauri/src/lib.rs) 的 `run()`：

```rust
pub fn run() {
    tauri::Builder::default()
        .manage(acp::AcpManager::new(acp_session_file()))
        .plugin(tauri_plugin_single_instance::init(...))
        .setup(|app| { ... })
        .invoke_handler(tauri::generate_handler![...])
        .run(tauri::generate_context!())
        .expect("failed to run DSH Companion");
}
```

这一行里按顺序发生 5 件事：

| 顺序 | 代码 | 作用 |
|---|---|---|
| 1 | `.manage(...)` | 注册全局状态 `AcpManager` |
| 2 | `.plugin(single_instance)` | 安装单实例插件 |
| 3 | `.setup(...)` | 注册“应用就绪后”的回调 |
| 4 | `.invoke_handler(...)` | 注册前端可调用命令 |
| 5 | `.run(generate_context!())` | 读取配置、创建窗口、进入事件循环 |

### 2.1 `.manage(AcpManager)`

```rust
.manage(acp::AcpManager::new(acp_session_file()))
```

`acp_session_file()` 返回：

```text
%LOCALAPPDATA%\DSH Companion\acp-session-id
```

`AcpManager` 此刻只是被创建，**还没有启动 ACP 子进程**：

```rust
pub struct AcpManager {
    client: Mutex<Option<Arc<AcpClient>>>,
    session_file: PathBuf,
}
```

- `client = None`：尚未连接；
- 第一次 `acp_handshake` 时才真正启动 `dsh --profile acp`。

后续命令通过：

```rust
manager: State<'_, acp::AcpManager>
```

拿到这个全局对象。

### 2.2 单实例插件

```rust
.plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.set_focus();
    }
}))
```

行为：

```text
第一次启动 → 正常创建窗口
第二次启动 → 新进程立刻退出
             回调把已有窗口 show + focus
```

这就是为什么桌宠不会出现两个。

---

## 3. 阶段 2：`generate_context!()` 读取配置

```rust
.run(tauri::generate_context!())
```

这是一个**编译期宏**，读取：

- [tauri.conf.json](../apps/companion/src-tauri/tauri.conf.json)
- 图标文件
- 前端构建产物目录 `../dist`

然后把这些内容嵌入二进制。

所以：

```text
修改 tauri.conf.json 后必须重新编译
```

### 3.1 窗口配置

```json
{
  "label": "main",
  "width": 370,
  "height": 220,
  "transparent": true,
  "decorations": false,
  "alwaysOnTop": true,
  "resizable": false,
  "shadow": false,
  "skipTaskbar": true,
  "visible": true
}
```

| 配置 | 效果 |
|---|---|
| `label: "main"` | 后续 `get_webview_window("main")` 能找到它 |
| `transparent` | 窗口背景透明，能看到桌面 |
| `decorations: false` | 没有标题栏和边框 |
| `alwaysOnTop` | 浮在其他窗口上方 |
| `skipTaskbar` | 不占任务栏 |
| `shadow: false` | 避免透明窗口出现方形阴影 |
| `visible: true` | 创建时可见 |

### 3.2 前端资源从哪来

生产构建：

```text
apps/companion/dist/index.html
        │ 被嵌入
        ▼
WebView 加载 tauri://localhost（Windows 上为 http://tauri.localhost）
```

开发模式：

```text
tauri dev
   → beforeDevCommand: pnpm dev
   → Vite 启动 http://localhost:1420
   → 窗口加载 devUrl
```

### 3.3 CSP

```json
"csp": "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src ipc: http://ipc.localhost"
```

限制 WebView：

- 只能加载自身资源；
- 允许内联样式；
- 只允许通过 IPC 与 Rust 通信；
- 不允许随意访问外网。

---

## 4. 阶段 3：窗口创建与 WebView 加载

Tauri 根据配置创建：

```text
HWND（原生窗口）
  └─ WebView2 控件
       └─ 加载 index.html
```

[index.html](../apps/companion/index.html)：

```html
<main id="app"></main>
<script type="module" src="/src/main.ts"></script>
```

生产构建后，`main.ts` 被打包成：

```text
assets/index-xxxx.js
assets/index-xxxx.css
```

此时 `#app` 还是空的，屏幕上什么都没有。

---

## 5. 阶段 4：`setup` 回调

窗口创建后，Tauri 调用 `setup`。

> WebView 资源加载是异步的，`setup` 与前端 JS 启动几乎同时发生，不要依赖严格先后顺序。

setup 中做四件事。

### 5.1 测试模式隐藏窗口

```rust
if smoke_test_mode() {
    if let Some(window) = app.get_webview_window("main") {
        window.hide()?;
    }
}
```

`smoke_test_mode()` 检查环境变量：

```text
DSH_COMPANION_SMOKE_TEST=1
```

这是给 [smoke-native.ps1](../scripts/smoke-native.ps1) 用的，避免测试时屏幕闪烁。

### 5.2 创建托盘菜单

```rust
let show = MenuItem::with_id(app, "show", "显示桌宠", true, None::<&str>)?;
let hide = MenuItem::with_id(app, "hide", "隐藏桌宠", true, None::<&str>)?;
let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
let menu = Menu::with_items(app, &[&show, &hide, &quit])?;
```

三个菜单项 ID：

```text
show / hide / quit
```

### 5.3 创建托盘图标并绑定事件

```rust
TrayIconBuilder::new()
    .tooltip("DSH Companion")
    .menu(&menu)
    .on_menu_event(|app, event| match event.id.as_ref() {
        "show" => { ... show + focus ... }
        "hide" => { ... hide ... }
        "quit" => app.exit(0),
        _ => {}
    })
    .on_tray_icon_event(...)
    .build(app)?;
```

关键点：

- 点击“显示桌宠”会先 `set_ignore_cursor_events(false)`，再 `show()`；
- 左键单击托盘图标也会显示窗口；
- “退出”调用 `app.exit(0)`。

为什么显示时要恢复鼠标事件？

因为点击穿透开启后，窗口完全不接收鼠标，用户无法点界面上的“恢复交互”，只能靠托盘救回来。

### 5.4 原生自检模式

```rust
if let Some(result_path) = native_self_test_path() {
    window.hide()?;
    window.set_ignore_cursor_events(true)?;
    window.set_ignore_cursor_events(false)?;
    std::fs::write(result_path, r#"{"trayInitialized":true,...}"#)?;
    app.handle().exit(0);
}
```

`DSH_COMPANION_NATIVE_SELF_TEST` 指向一个 JSON 文件。

[native-self-test.ps1](../scripts/native-self-test.ps1) 用它验证：

- 托盘能初始化；
- 点击穿透能开；
- 点击穿透能关；
- 程序能正常退出。

---

## 6. 阶段 5：注册前端可调用的命令

```rust
.invoke_handler(tauri::generate_handler![
    set_click_through,
    dsh::probe_dsh_environment,
    dsh::acp_handshake,
    dsh::acp_prompt_stream,
    dsh::acp_cancel,
    dsh::acp_disconnect,
    balance::deepseek_credential_status,
    balance::save_deepseek_api_key,
    balance::delete_deepseek_api_key,
    balance::get_deepseek_balance
])
```

这相当于一张路由表：

```text
前端 invoke("acp_handshake")
        │
        ▼
Rust fn acp_handshake(...)
```

前端：

```ts
invoke("acp_handshake", { workingDirectory: "C:\\DSHCompanion" })
```

Rust：

```rust
pub async fn acp_handshake(
    working_directory: String,
    manager: State<'_, acp::AcpManager>,
) -> Result<AcpHandshake, String>
```

参数名会自动从 camelCase 映射到 snake_case。

---

## 7. 阶段 6：前端 JS 开始执行

WebView 加载打包后的 JS，开始执行 [main.ts](../apps/companion/src/main.ts)。

### 7.1 import 阶段

```ts
import { invoke } from "@tauri-apps/api/core";
import type { DisplayMode, NormalizedDshState } from "@dsh-companion/protocol";
import { TauriDshAdapter } from "./dsh-adapter";
import "./styles.css";
```

- `invoke`：调用 Rust 命令；
- 协议类型：只用于 TypeScript 检查，运行时不存在；
- `TauriDshAdapter`：封装 ACP 调用；
- `styles.css`：Vite 注入为 `<style>` 或独立 CSS 文件。

### 7.2 找到根节点

```ts
const appElement = document.querySelector<HTMLElement>("#app");
if (!appElement) throw new Error("Missing #app root");
const app: HTMLElement = appElement;
const adapter = new TauriDshAdapter();
```

`#app` 来自 `index.html`。

### 7.3 初始化状态

```ts
let displayMode: DisplayMode = "pet";
let dshState: NormalizedDshState = "offline";
let clickThrough = false;
let busy = false;
let connectionDetail = "正在连接 DSH ACP…";
let credentialConfigured = false;
let balanceLoading = false;
let balance: BalanceResponse | undefined;
let balanceMessage = "正在检查余额凭据…";
let messages: ChatMessage[] = [
  { role: "assistant", text: "你好，我是由 DSH 托管的桌面助手。..." },
];
```

此刻默认：

```text
模式：桌宠
DSH 状态：离线
余额：未知
消息：一条欢迎语
```

### 7.4 注册右键屏蔽

```ts
window.addEventListener("contextmenu", (event) => event.preventDefault());
```

桌宠窗口不需要浏览器右键菜单。

### 7.5 启动两个异步任务

```ts
void Promise.allSettled([connect(), loadCredentialStatus()]);
```

并行做两件事：

```text
connect()              → 连接 ACP
loadCredentialStatus() → 检查是否保存过 API Key
```

用 `allSettled` 而不是 `all`，是为了让其中一个失败不影响另一个。

---

## 8. 阶段 7：第一次渲染出桌宠

`connect()` 的第一行就是：

```ts
async function connect() {
  render();          // 先画界面
  try {
    await adapter.connect("C:\\DSHCompanion");  // 再连 DSH
    ...
  }
  render();          // 连完再更新状态
}
```

这个顺序很关键：

```text
render() 先执行
   → 桌宠立刻出现
   → 不必等 ACP 连接完成
```

### 8.1 `render()` 做了什么

`render()` 用模板字符串整体替换 `app.innerHTML`：

```ts
app.innerHTML = `
  <section class="companion mode-${displayMode}" data-state="${dshState}">
    <header class="status-pill">...</header>
    <button class="pet" id="pet">...</button>
    <aside class="panel">...</aside>
    <section class="chat-panel">...</section>
    <button class="orb" id="orb">...</button>
  </section>`;
```

关键 DOM：

| 元素 | 作用 |
|---|---|
| `section.companion.mode-pet` | 根容器，class 决定当前模式 |
| `header.status-pill` | 顶部状态（离线/已连接/思考中） |
| `button.pet` | 像素桌宠，点击打开聊天 |
| `aside.panel` | 左侧信息面板与按钮 |
| `section.chat-panel` | 聊天面板（默认隐藏） |
| `button.orb` | 余额球（默认隐藏） |

`data-state="offline"` 被 CSS 用来改变状态点颜色。

### 8.2 重新绑定事件

因为 `innerHTML` 会销毁旧节点，所以每次 render 都要重新绑定：

```ts
app.querySelectorAll("[data-mode]").forEach((button) => {
  button.addEventListener("click", () => {
    displayMode = button.dataset.mode;
    render();
  });
});

app.querySelector("#pet").addEventListener("click", () => {
  displayMode = "chat";
  render();
  app.querySelector("#prompt")?.focus();
});

app.querySelector("#pet").addEventListener("dblclick", () => {
  displayMode = "orb";
  render();
});
```

这就是一个朴素的“状态驱动视图”：

```text
修改状态变量
   → 调用 render()
   → 整个 DOM 重建
   → 重新绑定事件
```

### 8.3 CSS 让窗口变透明

[styles.css](../apps/companion/src/styles.css) 开头：

```css
html, body, #app {
  width: 100%;
  height: 100%;
  margin: 0;
  overflow: hidden;
  background: transparent;
}
```

配合 `"transparent": true`，桌面就能透出来。

桌宠本身：

```css
.pet {
  position: absolute;
  right: 28px;
  bottom: 28px;
  width: 116px;
  height: 112px;
  animation: breathe 2.4s ease-in-out infinite;
}
```

`breathe` 是关键帧动画，让桌宠轻微上下浮动。

### 8.4 模式如何切换显示

```css
.mode-orb .pet,
.mode-orb .panel { display: none; }
.mode-orb .orb { display: block; }

.mode-chat .pet,
.mode-chat .panel,
.mode-chat .orb { display: none; }
.mode-chat .chat-panel { display: block; }
```

切换模式不需要销毁窗口，只是换 class。

---

## 9. 阶段 8：ACP 连接在后台完成

`render()` 之后，`connect()` 继续：

```ts
await adapter.connect("C:\\DSHCompanion");
```

进入 [dsh-adapter.ts](../apps/companion/src/dsh-adapter.ts)：

```ts
this.#handshake = await this.invokeCommand("acp_handshake", {
  workingDirectory,
});
```

Rust [dsh.rs](../apps/companion/src-tauri/src/dsh.rs)：

```rust
pub async fn acp_handshake(
    working_directory: String,
    manager: State<'_, acp::AcpManager>,
) -> Result<acp::AcpHandshake, String> {
    manager.connect(&dsh_launcher(), &PathBuf::from(working_directory))
        .await
        .map_err(|error| error.to_string())
}
```

[AcpManager::connect](../apps/companion/src-tauri/src/acp.rs)：

```text
读取上次 Session ID
   → 启动 dsh --profile acp
   → initialize
   → session/resume（失败则 session/new）
   → 保存 Session ID
   → 返回 handshake
```

成功后前端：

```ts
dshState = "idle";
connectionDetail = "deepseek-harness-acp · ACP v1";
render();
```

状态点从红色离线变为绿色已连接。

失败也不会白屏：

```ts
dshState = "offline";
connectionDetail = `无法连接 DSH ACP：...`;
render();
```

桌宠仍然在，只是顶部显示离线。

---

## 10. 阶段 9：用户点击桌宠

```text
点击 .pet
   → displayMode = "chat"
   → render()
   → 聊天面板显示
   → 输入框自动聚焦
```

输入消息后：

```text
submitPrompt()
   → messages.push(user)
   → messages.push(assistant 空消息)
   → adapter.prompt()
   → invoke("acp_prompt_stream")
   → Rust ACP
   → dsh --profile acp
   → session/update 流式返回
   → Tauri emit "acp-stream-<uuid>"
   → adapter 的 AsyncGenerator
   → main.ts 追加文本
   → render()
```

每来一段文本就 render 一次，所以看起来是逐字出现的。

---

## 11. 阶段 10：托盘与点击穿透

### 11.1 托盘“隐藏桌宠”

```text
Rust window.hide()
```

WebView 不销毁，状态仍保留在内存里。

### 11.2 托盘“显示桌宠”

```text
set_ignore_cursor_events(false)
window.show()
window.set_focus()
```

窗口重新出现，并恢复鼠标交互。

### 11.3 点击穿透

前端按钮：

```ts
clickThrough = !clickThrough;
await invoke("set_click_through", { enabled: clickThrough });
```

Rust：

```rust
window.set_ignore_cursor_events(enabled)
```

开启后：

```text
整个窗口不接收鼠标
→ 鼠标事件落到桌面或其他窗口
```

代价是：**你自己也点不到界面**，只能通过托盘恢复。

还有一件值得知道的事实：

> 透明窗口的“透明区域”仍然属于窗口，默认也会拦截鼠标。
> 因此即使看起来只有桌宠一小块，整个 370×220 区域都会挡住桌面点击。

这就是点击穿透功能存在的原因。

---

## 12. 完整时间线

```text
[Windows]
  dsh-companion.exe
        │
        ▼
[main.rs]
  dsh_companion_lib::run()
        │
        ▼
[lib.rs]
  Builder::default()
    ├─ manage(AcpManager)          // 只创建，不连接
    ├─ plugin(single_instance)     // 防重复启动
    ├─ setup(...)                  // 托盘、测试模式
    ├─ invoke_handler(...)         // 注册命令
    └─ run(generate_context!())    // 读配置、建窗口
                │
                ▼
[WebView2]
  加载 index.html
        │
        ▼
[main.ts]
  初始化状态
        │
        ├─ render()                // 立刻画出桌宠
        │
        └─ connect()
              │ invoke("acp_handshake")
              ▼
        [Rust dsh.rs]
              │
              ▼
        [Rust acp.rs]
              │ 启动 dsh --profile acp
              │ initialize + session/resume|new
              ▼
        返回 handshake
              │
              ▼
        dshState = "idle"
        render()                   // 状态点变绿
```

---

## 13. 调试入口

### 13.1 前端

```powershell
pnpm dev
```

开发模式会：

- 启动 Vite；
- 打开 Tauri 窗口；
- 支持 WebView 开发者工具（开发构建通常可用 `Ctrl+Shift+I`）。

`main.ts` 里已经屏蔽了右键菜单，所以不能靠右键打开检查器。

### 13.2 Rust

```powershell
cargo run --manifest-path apps/companion/src-tauri/Cargo.toml
```

或直接查看编译输出：

```powershell
pnpm --filter @dsh-companion/app tauri build --debug --no-bundle
```

### 13.3 ACP

```powershell
cargo run --manifest-path apps/companion/src-tauri/Cargo.toml --bin acp_persistent_probe
cargo run --manifest-path apps/companion/src-tauri/Cargo.toml --bin acp_resume_probe
```

### 13.4 环境变量

| 变量 | 作用 |
|---|---|
| `DSH_CLI_PATH` | 指定 `dsh.cmd` 路径 |
| `DSH_COMPANION_SMOKE_TEST` | 启动后隐藏窗口，供生命周期测试 |
| `DSH_COMPANION_NATIVE_SELF_TEST` | 执行托盘/点击穿透自检并写结果文件 |

---

## 14. 几个容易误解的点

1. **桌宠不是一张图片**
   它是 CSS 画的：`.face`、`.ear`、`.face i`、`.face b` 组合成像素脸。

2. **窗口不是“点哪算哪”**
   整个矩形窗口都接收鼠标，透明区域也会挡住桌面，所以需要点击穿透。

3. **渲染不是增量更新**
   每次 `render()` 都重建整个 DOM，简单但会丢失输入框焦点、滚动位置等，所以代码里手动恢复焦点和滚动。

4. **ACP 是懒连接**
   应用启动时不会立刻拉起 `dsh --profile acp`，第一次 `acp_handshake` 才启动。

5. **WebView 永远拿不到 API Key**
   `save_deepseek_api_key` 只接收一次输入；`deepseek_credential_status` 只返回 `{ configured, storage }`。

6. **托盘显示/隐藏不经过前端**
   是 Rust 直接操作窗口，所以即使 WebView 卡住，托盘仍然可用。
