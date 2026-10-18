import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const DEFAULT_CONFIG = Object.freeze({
  enabled: true,
  closeWithDsh: true,
  executable: "",
  executableArgs: [],
});

export default function apply(ctx, config = {}) {
  const options = { ...DEFAULT_CONFIG, ...config };
  if (!options.enabled) return;

  let child;
  let disposed = false;

  const log = (level, message) => {
    const logger = ctx?.logger;
    if (logger && typeof logger[level] === "function") logger[level](message);
    else console[level === "warning" ? "warn" : level]?.(`[dsh-companion] ${message}`);
  };

  const start = () => {
    if (child && child.exitCode === null) return child;

    const executable = options.executable
      ? (isAbsolute(options.executable) ? options.executable : resolve(packageRoot, options.executable))
      : resolve(packageRoot, "bin", "dsh-companion.exe");

    if (!existsSync(executable)) {
      log("warning", `Companion executable not found: ${executable}. Install a release package or configure an absolute executable path.`);
      return undefined;
    }

    child = spawn(executable, [...options.executableArgs, "--managed-by-dsh", `--dsh-pid=${process.pid}`], {
      detached: false,
      stdio: "ignore",
      windowsHide: true,
      shell: process.platform === "win32" && /\.(cmd|bat)$/i.test(executable),
      env: {
        ...process.env,
        DSH_COMPANION_MANAGED: "1",
        DSH_PARENT_PID: String(process.pid),
      },
    });

    child.once("error", (error) => log("error", `Companion failed to start: ${error.message}`));
    child.once("exit", (code) => {
      if (!disposed) log("warning", `Companion exited unexpectedly with code ${code ?? "unknown"}`);
      child = undefined;
    });

    log("info", `Started companion process ${child.pid}`);
    return child;
  };

  start();

  const stop = () => {
    disposed = true;
    if (options.closeWithDsh && child && child.exitCode === null) child.kill();
    child = undefined;
  };

  if (ctx && typeof ctx.on === "function") ctx.on("dispose", stop);
  return { start, stop, status: () => ({ running: Boolean(child && child.exitCode === null), pid: child?.pid }) };
}
