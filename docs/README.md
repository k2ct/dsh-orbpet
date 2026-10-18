# 项目文档

本目录包含架构、协议、安全、代码地图和启动流程。建议按以下顺序阅读。

## 入门

| 文档 | 内容 |
|---|---|
| [README](../README.md) | 功能、安装、构建、发布 |
| [architecture.md](architecture.md) | 三个进程的分工与稳定边界 |
| [code-map.md](code-map.md) | 逐目录、逐文件说明 |
| [startup-flow.md](startup-flow.md) | 从 EXE 启动到显示桌宠的完整调用链 |

## 协议与安全

| 文档 | 内容 |
|---|---|
| [acp.md](acp.md) | ACP v1 握手、Prompt、流式事件、取消、Session 恢复 |
| [security.md](security.md) | 信任边界、凭据存储、残留风险 |

## 验证与状态

| 文档 | 内容 |
|---|---|
| [m0-status.md](m0-status.md) | 各阶段验证证据与未完成项 |

## 在新电脑上继续开发

1. 安装 Windows 10/11、WebView2、Node.js 20+、pnpm 11、Rust stable MSVC、Visual Studio 2022 C++ Build Tools。
2. 安装 DeepSeek Harness。
3. 克隆仓库并安装依赖：

```powershell
git clone https://github.com/k2ct/dsh-orbpet.git
cd dsh-orbpet
pnpm install --frozen-lockfile
pnpm check
pnpm test
```

4. 启动开发窗口：

```powershell
pnpm dev
```

5. 如果本机没有全局 Node/pnpm，可临时把它们加入 PATH：

```powershell
$env:PATH = "C:\path\to\node\bin;$env:PATH"
```

6. 本机构建 Release 还需要 MSVC 环境：

```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64
$env:PATH = "C:\Users\<you>\.cargo\bin;$env:PATH"
powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 -Clean
```

## 文档维护约定

- 修改进程边界、协议或安全策略时，同步更新 `architecture.md`、`acp.md` 或 `security.md`。
- 新增目录或关键文件时，更新 `code-map.md`。
- 修改启动顺序、窗口创建或前端初始化时，更新 `startup-flow.md`。
- 不在文档中写入真实 API Key、Cookie、Token 或本机绝对路径。
