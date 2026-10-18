# Third-party notices

This repository currently contains original implementation code. No source code or artwork has been copied from the surveyed projects.

Runtime libraries used for secure balance support:

- `keyring-core` and `windows-native-keyring-store`, maintained by the Open Source Cooperative and licensed MIT OR Apache-2.0, provide Windows Credential Manager storage for the DeepSeek API key.
- `reqwest`, licensed MIT OR Apache-2.0, performs the official HTTPS balance request.

Other direct dependencies:

| Dependency | License |
|---|---|
| Tauri 2 and official plugins | MIT OR Apache-2.0 |
| Tokio, serde, serde_json, thiserror | MIT OR Apache-2.0 |
| Vite, TypeScript, tsx | MIT |
| `@tauri-apps/api`, `@tauri-apps/cli` | MIT OR Apache-2.0 |

Transitive Rust dependency names and versions are pinned in `apps/companion/src-tauri/Cargo.lock`; JavaScript versions are pinned in `pnpm-lock.yaml`. Run `cargo metadata` and `pnpm licenses list` if a complete machine-readable inventory is required for redistribution.

The application icon (`apps/companion/src-tauri/icons/icon.png` and `icon.ico`) was generated for this project from original CSS/pixel artwork and contains no third-party character or logo.

Projects used as architectural references:

| Project | URL | Observed license | Current use |
|---|---|---|---|
| dsh-whale-pixel-pet | https://github.com/1TRYOUT/dsh-whale-pixel-pet | MIT | Architecture and product-shape reference only |
| dsh-whale-girl-live2d | https://github.com/Andersen216/dsh-whale-girl-live2d | MIT code; separate non-commercial artwork terms | DSH integration reference only; no artwork included |
| AIssistant | https://github.com/12sncaksh/AIssistant | MIT code; separate Live2D terms | ACP integration reference only |
| DeepSeekBalanceMonitor | https://github.com/SrtaEstrella/DeepSeekBalanceMonitor | README states MIT | Credential-isolation reference only |
| NekoAI | https://github.com/nucket/NekoAI | MIT | Tauri desktop-pet architecture reference only |

Before any third-party code or assets are introduced, record the exact repository, commit, file, license, modifications, and redistribution requirements in this document.
