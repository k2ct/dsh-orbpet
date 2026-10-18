import { invoke } from "@tauri-apps/api/core";
import type { DisplayMode, NormalizedDshState } from "@dsh-companion/protocol";
import { TauriDshAdapter } from "./dsh-adapter";
import "./styles.css";

interface ChatMessage {
  role: "user" | "assistant" | "system";
  text: string;
}

interface BalanceInfo {
  currency: string;
  total_balance: string;
  granted_balance: string;
  topped_up_balance: string;
}

interface BalanceResponse {
  is_available: boolean;
  balance_infos: BalanceInfo[];
}

interface CredentialStatus {
  configured: boolean;
  storage: string;
}

const appElement = document.querySelector<HTMLElement>("#app");
if (!appElement) throw new Error("Missing #app root");
const app: HTMLElement = appElement;
const adapter = new TauriDshAdapter();

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
  { role: "assistant", text: "你好，我是由 DSH 托管的桌面助手。双击桌宠或点击“对话”即可开始。" },
];

function escapeHtml(value: string): string {
  return value.replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#39;",
    '"': "&quot;",
  })[character] ?? character);
}

function stateLabel(state: NormalizedDshState): string {
  return {
    offline: "离线",
    idle: "已连接",
    thinking: "思考中",
    working: "工作中",
    waiting_approval: "等待批准",
    error: "连接异常",
    completed: "已完成",
  }[state];
}

function primaryBalance(): BalanceInfo | undefined {
  return balance?.balance_infos.find((item) => item.currency === "CNY") ?? balance?.balance_infos[0];
}

function renderBalanceDetails(): string {
  if (!balance) return `<p class="balance-message">${escapeHtml(balanceMessage)}</p>`;
  return balance.balance_infos.map((item) => `
    <div class="balance-row">
      <strong>${escapeHtml(item.currency)} ${escapeHtml(item.total_balance)}</strong>
      <small>充值 ${escapeHtml(item.topped_up_balance)} · 赠送 ${escapeHtml(item.granted_balance)}</small>
    </div>`).join("");
}

function renderMessages(): string {
  return messages.map((message) => `
    <article class="message message-${message.role}">
      <span>${message.role === "user" ? "你" : message.role === "assistant" ? "DSH" : "系统"}</span>
      <p>${escapeHtml(message.text)}</p>
    </article>`).join("");
}

function render() {
  app.innerHTML = `
    <section class="companion mode-${displayMode}" data-state="${dshState}">
      <header class="status-pill" title="${escapeHtml(connectionDetail)}">
        <span class="dot"></span>
        <span>${stateLabel(dshState)}</span>
      </header>

      <button class="pet" id="pet" aria-label="打开 DSH 对话" title="单击打开对话，双击切换余额球">
        <span class="ear left"></span><span class="ear right"></span>
        <span class="face"><i></i><i></i><b></b></span>
      </button>

      <aside class="panel">
        <strong>DSH Companion · M1</strong>
        <p>${escapeHtml(connectionDetail)}</p>
        <div class="balance-summary">${renderBalanceDetails()}</div>
        <div class="actions">
          <button data-mode="chat">对话</button>
          <button data-mode="orb">余额球</button>
          <button data-mode="pet">桌宠</button>
          <button id="refresh-balance" ${balanceLoading ? "disabled" : ""}>${balanceLoading ? "刷新中" : "刷新余额"}</button>
          <button id="credential">${credentialConfigured ? "更换 Key" : "设置 Key"}</button>
          <button id="through">${clickThrough ? "恢复交互" : "点击穿透"}</button>
        </div>
      </aside>

      <section class="chat-panel" aria-label="DSH 对话">
        <header>
          <div><strong>DSH 对话</strong><small>${escapeHtml(connectionDetail)}</small></div>
          <button data-mode="pet" aria-label="关闭对话">×</button>
        </header>
        <div class="messages" id="messages">${renderMessages()}</div>
        <form id="prompt-form">
          <textarea id="prompt" rows="2" maxlength="8000" placeholder="输入消息，Enter 发送，Shift+Enter 换行" ${busy ? "disabled" : ""}></textarea>
          ${busy ? '<button type="button" id="cancel-prompt" class="cancel">取消</button>' : '<button type="submit">发送</button>'}
        </form>
      </section>

      <button class="orb" id="orb" title="展开桌宠">
        <small>DeepSeek</small>
        <strong>${primaryBalance() ? `${escapeHtml(primaryBalance()!.currency)} ${escapeHtml(primaryBalance()!.total_balance)}` : "--"}</strong>
        <em>${balanceLoading ? "刷新中…" : escapeHtml(balanceMessage)}</em>
      </button>
    </section>`;

  app.querySelectorAll<HTMLButtonElement>("[data-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      displayMode = button.dataset.mode as DisplayMode;
      render();
      if (displayMode === "chat") app.querySelector<HTMLTextAreaElement>("#prompt")?.focus();
    });
  });

  app.querySelector("#orb")?.addEventListener("click", () => {
    displayMode = "pet";
    render();
  });
  app.querySelector("#pet")?.addEventListener("click", () => {
    displayMode = "chat";
    render();
    app.querySelector<HTMLTextAreaElement>("#prompt")?.focus();
  });
  app.querySelector("#pet")?.addEventListener("dblclick", () => {
    displayMode = "orb";
    render();
  });
  app.querySelector("#through")?.addEventListener("click", toggleClickThrough);
  app.querySelector("#refresh-balance")?.addEventListener("click", () => void refreshBalance());
  app.querySelector("#credential")?.addEventListener("click", () => void configureCredential());
  app.querySelector("#cancel-prompt")?.addEventListener("click", () => void cancelPrompt());

  const form = app.querySelector<HTMLFormElement>("#prompt-form");
  const textarea = app.querySelector<HTMLTextAreaElement>("#prompt");
  form?.addEventListener("submit", (event) => {
    event.preventDefault();
    if (textarea) void submitPrompt(textarea.value);
  });
  textarea?.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      form?.requestSubmit();
    }
  });

  const messagesElement = app.querySelector<HTMLElement>("#messages");
  if (messagesElement) messagesElement.scrollTop = messagesElement.scrollHeight;
}

async function loadCredentialStatus() {
  try {
    const status = await invoke<CredentialStatus>("deepseek_credential_status");
    credentialConfigured = status.configured;
    balanceMessage = status.configured ? "点击刷新余额" : "尚未设置 API Key";
    if (status.configured) await refreshBalance();
  } catch (error) {
    balanceMessage = `凭据存储不可用：${String(error)}`;
  }
  render();
}

async function configureCredential() {
  const apiKey = window.prompt("请输入 DeepSeek 官方 API Key。它将仅保存到 Windows Credential Manager，不会写入配置文件或日志。", "");
  if (apiKey === null) return;
  if (!apiKey.trim()) {
    balanceMessage = "API Key 不能为空";
    render();
    return;
  }
  try {
    const status = await invoke<CredentialStatus>("save_deepseek_api_key", { apiKey });
    credentialConfigured = status.configured;
    balanceMessage = "凭据已安全保存";
    await refreshBalance();
  } catch (error) {
    balanceMessage = `保存凭据失败：${String(error)}`;
    render();
  }
}

async function refreshBalance() {
  if (balanceLoading) return;
  if (!credentialConfigured) {
    balanceMessage = "请先设置 DeepSeek API Key";
    render();
    return;
  }
  balanceLoading = true;
  balanceMessage = "正在刷新余额…";
  render();
  try {
    balance = await invoke<BalanceResponse>("get_deepseek_balance");
    balanceMessage = balance.is_available ? "余额可用" : "余额不足";
  } catch (error) {
    balance = undefined;
    balanceMessage = `刷新失败：${String(error)}`;
  } finally {
    balanceLoading = false;
    render();
  }
}

async function toggleClickThrough() {
  clickThrough = !clickThrough;
  try {
    await invoke("set_click_through", { enabled: clickThrough });
  } catch (error) {
    console.warn("Tauri command unavailable in browser preview", error);
    clickThrough = false;
  }
  render();
}

async function cancelPrompt() {
  if (!busy) return;
  try {
    await adapter.cancel();
    connectionDetail = "正在取消当前回答…";
  } catch (error) {
    messages.push({ role: "system", text: `取消失败：${String(error)}` });
  }
  render();
}

async function submitPrompt(rawText: string) {
  const text = rawText.trim();
  if (!text || busy) return;

  messages.push({ role: "user", text });
  busy = true;
  dshState = "thinking";
  render();

  messages.push({ role: "assistant", text: "" });
  const responseIndex = messages.length - 1;
  for await (const event of adapter.prompt({ text, workingDirectory: "C:\\DSHCompanion" })) {
    if (event.type === "status") {
      dshState = event.state;
      if (event.state === "thinking") connectionDetail = "ACP 会话已连接，正在生成回答";
    }
    if (event.type === "text-delta") messages[responseIndex].text += event.text;
    if (event.type === "completed") {
      connectionDetail = "ACP 会话保持连接";
      if (messages[responseIndex].text === "") messages[responseIndex].text = "（回答已结束，没有文本输出）";
    }
    if (event.type === "error") {
      if (messages[responseIndex].text === "") messages.splice(responseIndex, 1);
      messages.push({ role: "system", text: friendlyError(event.message) });
      connectionDetail = "ACP 可用，但当前请求失败";
    }
    render();
  }

  busy = false;
  if (dshState === "completed") setTimeout(() => {
    dshState = "idle";
    render();
  }, 1400);
  render();
}

function friendlyError(message: string): string {
  if (message.includes("no API key") || message.includes("MISSING_CREDENTIAL")) {
    return "DSH ACP 已连接，但尚未配置 DeepSeek 模型凭据。请先在 DSH 的模型设置中保存 API Key。";
  }
  return `DSH 请求失败：${message}`;
}

async function connect() {
  render();
  try {
    await adapter.connect("C:\\DSHCompanion");
    const handshake = adapter.handshake();
    dshState = "idle";
    connectionDetail = handshake
      ? `${handshake.agentName} · ACP v${handshake.protocolVersion}${handshake.resumed ? " · 已恢复会话" : ""}`
      : "DSH ACP 已连接";
  } catch (error) {
    dshState = "offline";
    connectionDetail = `无法连接 DSH ACP：${friendlyError(String(error))}`;
  }
  render();
}

window.addEventListener("contextmenu", (event) => event.preventDefault());
void Promise.allSettled([connect(), loadCredentialStatus()]);
