# dsh-desktop-companion-plugin

DSH Cordis bundle that starts and stops the native DSH Desktop Companion with the host profile lifecycle.

This package is normally distributed as part of the DSH Desktop Companion GitHub Release and contains `bin/dsh-companion.exe`.

## Local installation

```powershell
dsh plugin --profile companion add "file:C:/path/to/dsh-desktop-companion-plugin"
```

The default executable path is resolved relative to this package:

```text
bin/dsh-companion.exe
```

Optional configuration:

```yaml
- id: dsh-desktop-companion
  name: dsh-desktop-companion-plugin
  config:
    enabled: true
    closeWithDsh: true
    executable: 'C:\absolute\path\dsh-companion.exe'
    executableArgs: []
```

DSH compatibility: `>=0.2.1-rc.2 <0.3.0`.
