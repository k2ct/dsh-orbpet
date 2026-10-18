# DSH Desktop Companion

[![CI](https://github.com/k2ct/DSHCompanion/actions/workflows/ci.yml/badge.svg)](https://github.com/k2ct/DSHCompanion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D6)](https://www.microsoft.com/windows)

涓€涓敱 DeepSeek Harness锛圖SH锛塒lugin 鑷姩鎵樼鐨?Windows 鍘熺敓妗岄潰浼翠荆锛屾妸 **浣欓鎮诞鐞冦€佸儚绱犳瀹犲拰 DSH 瀵硅瘽** 鍚堝苟鍒板悓涓€涓?Tauri 搴旂敤涓€傚畠閫氳繃 ACP stdio 涓?DSH 閫氫俊锛屼笉瑕佹眰鎵撳紑 DSH 缃戦〉绔€?
> 椤圭洰澶勪簬 `0.1.0` 棰勫彂甯冮樁娈点€傛牳蹇冮摼璺凡缁忓彲鐢ㄥ苟鏈夎嚜鍔ㄥ寲娴嬭瘯锛屼絾瀹夎绋嬪簭銆佽瑙夎祫浜у拰涓嶅悓鏈哄櫒涓婄殑鍏煎鎬т粛闇€缁х画楠岃瘉銆?
## 鍔熻兘

- 妗屽疇銆佷綑棰濈悆銆佽亰澶╀笁绉嶆樉绀烘ā寮?- 閫忔槑銆佺疆椤躲€佹棤杈规銆佽烦杩囦换鍔℃爮鐨勫師鐢熺獥鍙?- 鎵樼洏鏄剧ず銆侀殣钘忓拰閫€鍑?- 鐐瑰嚮绌块€忎笌鎭㈠浜や簰
- DSH Plugin 鑷姩鍚姩鍜屽叧闂?Companion
- ACP v1 NDJSON 闀挎湡杩炴帴鍜?Session 澶嶇敤
- ACP 娴佸紡鏂囨湰浜嬩欢銆佸彇娑堝洖绛斿拰 Session 鎭㈠
- DeepSeek 瀹樻柟 `/user/balance` 浣欓鏌ヨ
- Windows Credential Manager 瀹夊叏淇濆瓨 DeepSeek API Key
- 鍗曞疄渚嬨€佺敓鍛藉懆鏈熷拰瀛ゅ効杩涚▼鑷姩鍖栨祴璇?
## 鏋舵瀯

```text
DSH Desktop / CLI runtime
        鈹?        鈹?Cordis Plugin lifecycle
        鈻?dsh-desktop-companion-plugin
        鈹?        鈹?starts / stops
        鈻?DSH Companion (Tauri 2)
   鈹溾攢 transparent pet / orb / chat UI
   鈹溾攢 Windows Credential Manager
   鈹溾攢 DeepSeek official balance API
   鈹斺攢 dsh --profile acp (stdio, ACP v1)
```

Companion 涓嶄緷璧?DSH GUI 鐨勯殢鏈?localhost 绔彛鎴栫鏈?Electron IPC锛屼篃涓嶄細缁曡繃 DSH 鐨勫鎵瑰拰 Sandbox銆?
## 褰撳墠鐘舵€?
| 妯″潡 | 鐘舵€?|
|---|---|
| Tauri 鍘熺敓绐楀彛銆佹墭鐩樸€佸崟瀹炰緥 | 宸插疄鐜?|
| 妗屽疇銆佷綑棰濈悆銆佽亰澶?UI | 宸插疄鐜板熀纭€鐗堟湰 |
| Plugin 鑷姩鎵樼 | 宸插湪闅旂 profile 楠岃瘉 |
| ACP 闀挎湡杩涚▼銆佹祦寮忎簨浠躲€佸彇娑?| 宸插疄鐜?|
| ACP Session 鎸佷箙鍖栦笌鎭㈠ | 宸插疄鐜?|
| Windows Credential Manager | 宸插疄鐜板苟瀹屾垚鍐欏叆/璇诲彇/鍒犻櫎鎺㈤拡 |
| DeepSeek 瀹樻柟浣欓 | 宸插疄鐜帮紱鐪熷疄浣欓闇€瑕佺敤鎴疯嚜宸辩殑 API Key |
| Release EXE / NSIS | 鍙敱鍙戝竷鑴氭湰鍜?CI 鏋勫缓 |
| 澶?DPI銆佸鏄剧ず鍣ㄣ€佸姩鐢昏祫浜?| 寰呭畬鍠?|

璇︾粏璇佹嵁瑙?[`docs/m0-status.md`](docs/m0-status.md)銆?
## 绯荤粺瑕佹眰

- Windows 10 鎴?Windows 11锛坸64锛?- Microsoft Edge WebView2 Runtime
- DeepSeek Harness `>=0.2.1-rc.2 <0.3.0`
- 寮€鍙戠幆澧冿細
  - Node.js 20+
  - pnpm 11
  - Rust stable锛圡SVC target锛?  - Visual Studio 2022 Build Tools锛屽寘鍚?Desktop development with C++

## 蹇€熷紑濮嬶細寮€鍙?
```powershell
git clone https://github.com/k2ct/DSHCompanion.git
cd DSHCompanion
pnpm install --frozen-lockfile
pnpm check
pnpm test
pnpm dev
```

`pnpm dev` 鍚姩鐨勬槸 Tauri 寮€鍙戠獥鍙ｏ紝涓嶄細涓诲姩鎵撳紑 DSH Web profile銆侰ompanion 涓?DSH 鐨勫璇濋€氫俊浣跨敤锛?
```text
dsh --profile acp
```

### 鏋勫缓 Debug 鐗堟湰

```powershell
pnpm --filter @dsh-companion/app tauri build --debug --no-bundle
```

### 鏋勫缓 GitHub Release 浜х墿

```powershell
pwsh -File scripts/build-release.ps1 -Clean
```

浜х墿浼氱敓鎴愬埌琚?Git 蹇界暐鐨?`release/` 鐩綍锛屽寘鎷細

- Companion Release EXE
- DSH Plugin 鍒嗗彂鐩綍鍜屽帇缂╁寘
- NSIS 瀹夎绋嬪簭锛堟瀯寤虹幆澧冩敮鎸佹椂锛?- SHA-256 鏍￠獙鏂囦欢

## 瀹夎 DSH Plugin

姝ｅ紡 Release 鐨?Plugin 鍖呭唴搴斿寘鍚細

```text
dsh-desktop-companion-plugin/
鈹溾攢 bin/dsh-companion.exe
鈹溾攢 lib/index.js
鈹溾攢 package.json
鈹溾攢 cordis.patch.yml
鈹溾攢 LICENSE
鈹斺攢 THIRD_PARTY_NOTICES.md
```

涓嬭浇骞惰В鍘?Release 鍚庯紝鍦?PowerShell 涓繍琛岋細

```powershell
pwsh -File scripts/install-plugin.ps1 -PackagePath .\dsh-desktop-companion-plugin
```

鍗歌浇锛?
```powershell
pwsh -File scripts/uninstall-plugin.ps1
```

瀹夎鑴氭湰榛樿鐩爣鏄悕涓?`companion` 鐨勯潪淇濈暀 DSH profile銆傞櫎闈炰綘鏄庣‘浜嗚В DSH Desktop profile 鐨勭鐞嗘柟寮忥紝鍚﹀垯涓嶈閫氳繃 CLI 淇敼淇濈暀鐨?`desktop` profile銆?
## 閰嶇疆 DeepSeek 浣欓

鍦?Companion 涓偣鍑烩€滆缃?Key鈥濓紝杈撳叆 DeepSeek 瀹樻柟 API Key銆侹ey 浼氫繚瀛樺埌 Windows Credential Manager锛?
- 涓嶅啓鍏?`.env` 鎴栭厤缃枃浠?- 涓嶈繑鍥炵粰 WebView
- 涓嶈繘鍏ユ棩蹇?- 涓嶉殢 Git 鎴?Release 鍖呭垎鍙?
浣欓鍙姹傚畼鏂瑰湴鍧€锛?
```text
GET https://api.deepseek.com/user/balance
```

鏇村璇存槑瑙?[`docs/security.md`](docs/security.md)銆?
## 楠岃瘉鍛戒护

```powershell
pnpm check
pnpm test
pwsh -File scripts/check-environment.ps1
pwsh -File scripts/probe-dsh-acp.ps1
pwsh -File scripts/native-self-test.ps1
pwsh -File scripts/smoke-native.ps1 -Iterations 20
```

杩欎簺鎺㈤拡涓嶈姹傚惎鍔?DSH Web profile銆?
## 浠撳簱缁撴瀯

```text
apps/companion/          Tauri 妗岄潰搴旂敤
packages/protocol/       Plugin / Companion 绋冲畾娑堟伅濂戠害
packages/pet-state/      DSH 鐘舵€佸埌妗屽疇鐘舵€佺殑褰掍竴鍖栭€昏緫
plugins/dsh-companion/   DSH Cordis Plugin
scripts/                 鏋勫缓銆佸畨瑁呭拰娴嬭瘯鑴氭湰
docs/                    鏋舵瀯銆佸畨鍏ㄥ拰楠岃瘉璇佹嵁
.github/                  CI銆両ssue 鍜?PR 妯℃澘
```

## 瀹夊叏鍘熷垯

- 涓嶈鍙栨祻瑙堝櫒 Cookie锛屼笉浣跨敤 DeepSeek 绉佹湁 Web 鎺ュ彛
- API Key 浠呯敱 Rust 鍚庣鍜?Windows Credential Manager 澶勭悊
- Companion 涓嶇粫杩?DSH 瀹℃壒鎴?Sandbox
- ACP 浣跨敤 stdio锛屼笉瀵瑰鐩戝惉鎺у埗绔彛
- 鏃ュ織涓嶅緱鍖呭惈 Bearer Token銆丆ookie 鎴栧嚟鎹?
鍙戠幇瀹夊叏闂璇烽槄璇?[`SECURITY.md`](SECURITY.md)锛屼笉瑕佸湪鍏紑 Issue 涓彁浜ょ瀵嗘垨婕忔礊鍒╃敤缁嗚妭銆?
## 寮€婧愪笌璐＄尞

- License锛歁IT锛岃 [`LICENSE`](LICENSE)
- 璐＄尞鎸囧崡锛歔`CONTRIBUTING.md`](CONTRIBUTING.md)
- 琛屼负鍑嗗垯锛歔`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- 鍙樻洿璁板綍锛歔`CHANGELOG.md`](CHANGELOG.md)
- 绗笁鏂硅鏄庯細[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)

椤圭洰鍊熼壌浜嗚嫢骞插紑婧愭瀹犲拰 DSH 闆嗘垚椤圭洰鐨勬灦鏋勬€濊矾锛屼絾褰撳墠娌℃湁澶嶅埗鍏舵簮浠ｇ爜鎴栫編鏈祫浜с€傜簿纭竟鐣岃褰曞湪绗笁鏂硅鏄庝腑銆?
## 鍙戝竷鍒?GitHub

1. 鍦?GitHub 鍒涘缓绌轰粨搴擄紙涓嶈鍒濆鍖?README銆乣.gitignore` 鎴?License锛夈€?2. 灏嗗崰浣嶉摼鎺ユ浛鎹负浣犵殑瀹為檯鐢ㄦ埛鍚嶆垨缁勭粐鍚嶏細

```powershell
pwsh -File scripts/init-github.ps1 -Owner <浣犵殑GitHub鐢ㄦ埛鍚? -SetRemote
```

3. 杩愯瀹屾暣鍙戝竷棰勬锛?
```powershell
pwsh -File scripts/preflight-release.ps1
```

4. 棣栨鎻愪氦骞舵帹閫侊細

```powershell
git add -A
git status --short
git commit -m "feat: initial DSH Desktop Companion release"
git push -u origin main
```

5. 鍒涘缓鐗堟湰鏍囩瑙﹀彂 Release 宸ヤ綔娴侊細

```powershell
git tag v0.1.0
git push origin v0.1.0
```

CI 浼氭墽琛?TypeScript/Vite 妫€鏌ャ€丯ode 娴嬭瘯銆丷ust 鏍煎紡鍜屾祴璇曪紱鏍囩鍙戝竷浼氭瀯寤?EXE銆丯SIS 瀹夎绋嬪簭銆丳lugin 鍖呬笌 `SHA256SUMS.txt`銆?
鍙戝竷鍚庡缓璁湪浠撳簱璁剧疆涓惎鐢細

- Branch protection锛堣姹?CI 閫氳繃锛?- Secret scanning 涓?push protection
- Private vulnerability reporting
- Dependabot alerts
