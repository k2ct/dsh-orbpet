# Contributing

感谢你为 DSH Desktop Companion 做贡献。

## 开始前

- 对较大的功能、协议或 UI 变更，请先创建 Issue 讨论。
- 不要提交 DeepSeek API Key、DSH Token、Cookie、账户余额截图或其他秘密。
- 不要提交来源或许可证不清晰的桌宠素材、Live2D 模型、音频或字体。
- 不要设计绕过 DSH 审批、权限或 Sandbox 的功能。

## 开发环境

需要 Windows 10/11、Node.js 20+、pnpm 11、Rust stable MSVC 和 Visual Studio 2022 C++ Build Tools。

```powershell
pnpm install --frozen-lockfile
pnpm check
pnpm test
```

原生验证：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/native-self-test.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-native.ps1 -Iterations 5
```

## 提交约定

建议使用 Conventional Commits：

- `feat:` 新功能
- `fix:` Bug 修复
- `docs:` 文档
- `test:` 测试
- `build:` 构建或依赖
- `refactor:` 不改变行为的重构

每个 PR 应：

1. 说明问题和方案；
2. 保持改动范围尽量小；
3. 增加或更新测试；
4. 更新相关文档和 `CHANGELOG.md`；
5. 通过 `pnpm check`、`pnpm test` 和适用的 Rust 测试；
6. 声明是否引入第三方代码或资产，并更新 `THIRD_PARTY_NOTICES.md`。

## 代码风格

- TypeScript 使用现有 `tsconfig` 和格式风格。
- Rust 提交前运行 `cargo fmt`。
- WebView 不应获得已保存的 API Key。
- ACP stdout 按 NDJSON 解析，必须容忍非 JSON 诊断行。
- Windows 进程和临时凭据测试后必须清理。

## Pull Request 检查

```powershell
powershell -ExecutionPolicy Bypass -File scripts/preflight-release.ps1 -SkipReleaseBuild
```

提交 PR 即表示你有权按项目 MIT License 提交这些改动。
