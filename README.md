# cdm

`cdm` is a terminal UI that deep-cleans your Mac: dev caches, build artifacts, leftover app data, device backups, dead simulators — and the large files you have not opened in months. It shows you exactly what and how big, and deletes only what you tick.

macOS only. Pure bash, no dependencies. Zero telemetry — the only network call `cdm` ever makes is fetching its own rule JSON.

## Run it

```bash
curl -sSL https://github.com/dungtran-apero/cdm/releases/latest/download/cdm | bash
```

There is no install step. The script runs straight from the pipe, scans, and hands you the TUI. When it exits, nothing of it is left on your Mac.

Dry run first — scans and reports, deletes nothing:

```bash
curl -sSL https://github.com/dungtran-apero/cdm/releases/latest/download/cdm | bash -s -- -n
```

## Keep it around (optional)

Only do this if you want to run `cdm` again without the URL. It is the one thing here that does leave a file behind:

```bash
mkdir -p ~/.local/bin
curl -sSL https://github.com/dungtran-apero/cdm/releases/latest/download/cdm -o ~/.local/bin/cdm
chmod +x ~/.local/bin/cdm
cdm
```

Make sure `~/.local/bin` is on your `PATH` (`export PATH="$HOME/.local/bin:$PATH"` in your shell rc). Re-run the `curl -o` line to update. To uninstall: `rm ~/.local/bin/cdm`.

## What it cleans

**1. Dev caches & build artifacts** — Xcode DerivedData and DeviceSupport, Go build & module cache, npm/npx/pnpm/yarn, JS build tools (Turbo, Vite, webpack, Parcel, ESLint), Gradle, Maven, sbt/Ivy, Cargo, Python (pip, uv, poetry, ruff, mypy), Ruby/Bundler, Bun, Deno, CocoaPods, SwiftPM, Composer, Bazel, Zig, cloud CLIs (kubectl, AWS, gcloud, Azure), Docker buildx, JetBrains, Playwright, and the Homebrew download cache.

**2. Electron, browser & app caches** — VS Code, Claude, Slack; Chrome, Brave, Edge, Vivaldi and Arc scanned per browser profile; Firefox; and crash/telemetry SDK caches (Sentry, Crashlytics, Sparkle).

**3. Project junk, grouped per repo** — `node_modules`, `dist`, `build`, `target`, `__pycache__`, and git-ignored files. Only ever what the repo itself git-ignores. Off by default; pass `-p` to enable it. Interactive runs offer it after the cache scan finishes.

**4. Docker / Podman** — `system prune -af`, opt-in. Named volumes are never touched.

**5. Orphaned app data** — Application Support, Caches and Preferences belonging to apps that are no longer installed.

**6. Deep clean (all opt-in)** — every other folder in `~/Library/Caches` and `~/Library/Logs` that no specific rule names (Apple's own skipped, nothing counted twice), saved window state, Mail's attachment cache, iPhone/iPad backups (one row per device, to the Trash), `.ipsw` firmware, simulators whose runtime is gone (`xcrun simctl delete unavailable`), Android system images and AVDs (one row each), Homebrew's old versions (`brew cleanup --prune=all`).

**7. Your large, long-unused files** — files of 200 MB+ in `~/Downloads`, `~/Desktop`, `~/Documents` and `~/Movies` not opened or changed in 90+ days, one row per file with its last-used date, listed as their own section at the bottom of the menu. Plus old `.dmg`/`.pkg`/`.iso` installers in Downloads. They are never pre-selected, `a`/`s`/`-y` never pick them, and a ticked file only ever goes to the Trash.

## Safety

- **Nothing is deleted without an itemized confirmation.** You see the plan and the sizes, then type `y`.
- **Caches are deleted permanently** — they regenerate on the next build.
- **Orphaned app data and git-ignored files go to the Trash**, so they are recoverable.
- **Never touched regardless of what the rules say:** `~/Documents`, `~/Desktop`, `~/Downloads`, `~/Pictures`, `~/.ssh`, and iCloud Drive. This guard sits below the rule engine — a rule cannot opt out of it.
- **Your own files are opt-in, one by one, and recoverable.** The large-file rows have their own, stricter gate: a regular file (never a folder, never a symlink) physically inside Downloads/Desktop/Documents/Movies, not in iCloud Drive, not inside a git repo or a package (Photos library, VM, Final Cut bundle, ...). The only action is moving it to the Trash.
- **A folder is only project junk if your repo git-ignores it.** Matching a name like `dist`, `build` or `Pods` is not enough — cdm verifies with git that the directory is ignored *and* untracked, so a tracked `build/` of release scripts or a committed `dist/` is left alone.
- **`.env*` files are never offered for deletion.** The project scan skips them even though they're git-ignored — they hold secrets and local config nothing regenerates.
- **App sandboxes and Apple/system-owned data are never touched.**
- The installed-app list is read from **LaunchServices**, so prefPanes, plugins and other non-`.app` bundles aren't mis-flagged as orphaned.
- `--dry-run` deletes nothing.
- Every run is logged to `~/.cdm/clean.log`.

## TUI keys

`cdm` shows your disk — total, used, free — before it scans, the most it could reclaim once the scan finishes, and what the disk looks like again after a clean.

| Key | Action |
| --- | --- |
| `↑` / `↓`, `k` / `j` | Move |
| `Space` | Toggle the selected item |
| `a` / `s` / `n` | Select all / safe defaults / none |
| `Enter` (or `d`) | Show the exact paths and sizes behind an item |
| `c` | Clean — builds an itemized plan, confirm with `y` |
| `q` (or `Esc`) | Quit |

After a clean it prints the receipt and asks what next: `r` rescan · `q` quit (the default — Enter or any other key does the same).

Items are sorted biggest-first. Safe regenerable caches are pre-selected; the Maven repository, Playwright browsers, crash logs, project folders and orphaned app data all start unchecked — `s` resets to that default selection.

## Editable rules

Targets live in JSON under `rules/`, not in code. Add or remove paths by editing these files:

| File | Contents |
| --- | --- |
| `index.json` | Manifest — which rule files load, and in what order |
| `dev-caches.json` | Dev caches & build artifacts |
| `app-caches.json` | Electron, browser & app caches |
| `containers.json` | Docker / Podman |
| `deep-clean.json` | Catch-all caches/logs, device backups, simulators, Homebrew, your large old files |
| `project-junk.json` | Per-repo project junk |
| `orphans.json` | Orphaned app data detection |

Each category is an object with `icon`, `name`, `desc`, `paths`, `default` (pre-selected or not) and `method` (`rm` to delete, `trash` to move to the Trash). Point `cdm` at your own set with `--patterns <dir-or-url>`.

A category may also carry `procs` — the process names of apps that would rewrite those caches while running (`"procs": ["Google Chrome", "Code"]`). `cdm` names any that are open before asking you to confirm, since clearing a cache under its own app just hands the space straight back. Names must match `pgrep -x` exactly.

Optional keys added for deep clean:

| Key | Effect |
| --- | --- |
| `perItem: true` | One menu row per matched path instead of one per category |
| `rest: true` | Catch-all: skip every path another rule already names |
| `exclude: [globs]` | Basename globs to leave out |
| `kind: "files"` | Your own files: `roots` (only inside Downloads/Desktop/Documents/Movies), optional `names`, `minSizeMB`, `minAgeDays`, `maxItems`, `maxDepth`, `prune`, `perItem`. Always Trash, never pre-selected |
| `kind: "simulators"` / `"brew"` | Row for `xcrun simctl delete unavailable` / `brew cleanup --prune=all` |

## Options

| Option | Effect |
| --- | --- |
| `-n`, `--dry-run` | Scan and report; delete nothing |
| `-y`, `--yes` | Non-interactive: clean the pre-selected safe caches, then exit. Never touches project folders, orphaned app data, your own files, or the Trash |
| `-p`, `--projects` | Also scan code repos for project junk |
| `--patterns SRC` | Load rules from a local directory or a base URL |
| `--no-color` | Disable ANSI color |
| `-h`, `--help` | Usage |

## Environment

| Variable | Effect |
| --- | --- |
| `CDM_REMOTE` | Base URL rules are fetched from when no local copy is found |
| `CDM_PATTERNS` | Rule source — a local directory or a base URL (same as `--patterns`) |

## Credits

Some cache locations were cross-checked against other open-source macOS cleaners:

- [PureMac](https://github.com/momenbasel/PureMac) — MIT
- [mac-cleaner-cli](https://github.com/guhcostan/mac-cleaner-cli) — MIT
- [mac-cleanup-go](https://github.com/2ykwang/mac-cleanup-go) — MIT
- [mac-cleanup-py](https://github.com/mac-cleanup/mac-cleanup-py) — Apache-2.0

The rules here are written independently for this tool's own schema, and each path was verified before being added.

## License

MIT — see [LICENSE](LICENSE).
