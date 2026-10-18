## Summary

Describe the problem and the smallest solution implemented.

## Verification

- [ ] `pnpm check`
- [ ] `pnpm test`
- [ ] `cargo test --manifest-path apps/companion/src-tauri/Cargo.toml --locked`
- [ ] Native smoke test, if Windows lifecycle behavior changed

## Security and compatibility

- [ ] No credentials, tokens, cookies, personal data, or build artifacts are committed.
- [ ] This change does not bypass DSH approval or sandbox controls.
- [ ] Credential and WebView boundaries remain intact.
- [ ] DSH compatibility impact is documented.

## Third-party code and assets

- [ ] No new third-party code or assets were introduced; or
- [ ] `THIRD_PARTY_NOTICES.md` and relevant license files were updated.

## Documentation

- [ ] README/docs/changelog were updated where needed.
