# Neovim LSP: native client, `nvim-lspconfig`, dev-shells, and Nix frameworks

Sources are primary: Neovim runtime docs/source at the exact version this box
runs (`0.12.5`), the `nvim-lspconfig` repo at `master`, `nix-direnv`/`nix develop`
docs, and the nixvim/nvf source trees. Version pins are inline.

## Executive answer

- **Neovim has a built-in LSP client** (`vim.lsp`) since 0.5; a plugin was never
  *required* for LSP — it was required for *server definitions*.
  ([`:help lsp`](https://neovim.io/doc/user/lsp.html) — "Nvim supports the Language Server Protocol (LSP) … acts as a client"; `vim.lsp` in `runtime/lua/vim/lsp.lua` @ v0.12.5)
- **`nvim-lspconfig` is not deprecated; `require('lspconfig')` is.** The plugin
  is now just a folder of `lsp/<server>.lua` config files that core's
  `vim.lsp.config` / `vim.lsp.enable` read off the runtimepath.
  ([nvim-lspconfig README, "Important"](https://github.com/neovim/nvim-lspconfig#important-))
- **You can configure real servers with zero plugins.** You hand-write `cmd`,
  `filetypes`, `root_markers`, and optionally `capabilities`/`init_options`/
  `settings` per server.
  ([`:help lsp-quickstart`](https://neovim.io/doc/user/lsp.html#lsp-quickstart))
- **The comment "nvim 0.12 bundles no server configs" is correct** — for `lsp/*.lua`.
  Verified locally and against `v0.12.5` source: the runtime has **no** `lsp/`
  directory and no bundled server configs.
  (`ls $VIMRUNTIME/lsp` on this machine → absent; `runtime/lua/vim/lsp.lua` @ v0.12.5 ships none)
  The nuance worth noting: Neovim does bundle two *in-process* servers in Lua
  (`runtime/lua/vim/pack/_lsp.lua`, referenced from `:help lsp-server`), but
  those are UI helpers, not external language servers.
- **Dev-shell-only servers are viable** because spawn inherits Neovim's process
  `PATH`; but the fragile part is *GUI/session* nvim launched from an env that
  has no dev-shell. Keep a global fallback set (as this repo already does).
- **Recommendation for this repo: keep core Neovim + `nvim-lspconfig`, keep the
  global `home/lsp.nix` list as the baseline, and add a dev-shell override hook**
  (a few lines, or nixvim's `packageFallback` behavior) — do **not** adopt nixvim
  or nvf.

---

## 1. Native LSP vs `vim.lsp` vs `nvim-lspconfig`

### `vim.lsp` (core) provides

- The whole **client/framework**: RPC transport over stdio (and TCP/socket via
  `vim.lsp.rpc.connect`), JSON-RPC framing, `initialize`/`shutdown`, capability
  negotiation, buffer change tracking, diagnostics, semantic tokens, completion,
  inlay hints, folding, document colors, and default keymaps (`gra`, `grn`,
  `grr`, `gri`, `gO`, `K`, …).
  ([`:help lsp`](https://neovim.io/doc/user/lsp.html); `runtime/lua/vim/lsp/rpc.lua` @ v0.12.5)
- Config plumbing: `vim.lsp.config()` (since 0.11) and `vim.lsp.enable()` (since
  0.11), plus the `lsp/<name>.lua` runtimepath convention.
  ([`:help vim.lsp.config()`](https://neovim.io/doc/user/lsp.html#vim.lsp.config()), [`:help vim.lsp.enable()`](https://neovim.io/doc/user/lsp.html#vim.lsp.enable()))
- Start machinery: `vim.lsp.start()` / `vim.lsp.start_client()` (the latter
  deprecated in favour of `vim.lsp.start()`).
  ([`:help vim.lsp.start()`](https://neovim.io/doc/user/lsp.html#vim.lsp.start()), `runtime/lua/vim/lsp.lua` @ v0.12.5)

### `nvim-lspconfig` adds

- **Server-specific data only**: a directory of `lsp/<server>.lua` files, each
  `return { cmd=…, filetypes=…, root_markers=…, settings=…, on_attach=… }`
  (see e.g. [`lsp/clangd.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/clangd.lua),
  [`lsp/basedpyright.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/basedpyright.lua),
  [`lsp/yamlls.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/yamlls.lua)).
- Legacy compatibility shims and commands (`:LspInfo`, `:LspStart`, …) in
  [`plugin/lspconfig.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/plugin/lspconfig.lua).
- It does **not** install servers, and it does **not** ship its own LSP engine.
  ([README](https://github.com/neovim/nvim-lspconfig#install): "nvim-lspconfig does not install language servers for you")

### The 0.11/0.12 API change

- 0.11 introduced the runtimepath convention and the new functions; 0.11 release
  notes list them as new:
  `vim.lsp.config()` "has been added … In addition, configurations can be
  specified in `lsp/<name>.lua`" and `vim.lsp.enable()` "has been added to enable
  servers."
  ([`news-0.11.txt`](https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/doc/news-0.11.txt), LSP "NEW FEATURES")
- `vim.lsp.config` merges, in increasing priority: `'*'`, then all `lsp/<config>.lua`
  on the runtimepath, then all `after/lsp/<config>.lua`, then literal
  `vim.lsp.config()` calls — using `vim.tbl_deep_extend('force', …)`.
  ([`:help lsp-config-merge`](https://neovim.io/doc/user/lsp.html#lsp-config-merge))
- **`require('lspconfig')` is deprecated, the plugin is not.** Deprecation message
  points at `vim.lsp.config`:
  [`lua/lspconfig.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig.lua)
  (`vim.deprecate('The \`require('lspconfig')\` "framework"', 'vim.lsp.config …')`).
  README's migration: use `vim.lsp.config('…')` to customize/define and
  `vim.lsp.enable('…')` to enable — not `require'lspconfig'.….setup{}`.
  ([README, Important + Migration](https://github.com/neovim/nvim-lspconfig#important-))
- Note the 0.11 shim in `plugin/lspconfig.lua` that reimplements `:LspStart`
  et al. on top of `vim.lsp.enable` when `nvim-0.11.2+`; the legacy configs
  under `lua/lspconfig/` are the deprecated part and "will be removed".
  ([README](https://github.com/neovim/nvim-lspconfig#important-))

### "nvim 0.12 bundles no server configs" — verdict

**Correct.** Verified two ways:

1. On this machine: `$VIMRUNTIME=/nix/store/…-neovim-unwrapped-0.12.5/share/nvim/runtime`,
   and `$VIMRUNTIME/lsp` **does not exist**. So there is no bundled `lsp/*.lua`.
2. In `neovim/neovim` @ `v0.12.5`, the runtime `lsp/` convention exists only as a
   *lookup path* (`nvim_get_runtime_file('lsp/%s.lua')` in
   [`runtime/lua/vim/lsp.lua`](https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/lua/vim/lsp.lua));
   no server files are shipped.

The only bundled "servers" are in-process Lua ones for `vim.pack`'s update UI
(`runtime/lua/vim/pack/_lsp.lua`), explicitly called out in
[`:help lsp-server`](https://neovim.io/doc/user/lsp.html#lsp-server) as an
example, not external language servers. The comment could be tightened to
"bundles no *external* server configs", but it is not wrong.

### Zero plugins: what you'd write by hand

One `vim.lsp.config(name, {…})` + `vim.lsp.enable(name)` per server. The fields
you own:

| field | purpose | source |
|---|---|---|
| `cmd` | argv to spawn (must be on `PATH`) | [`:help vim.lsp.Config`](https://neovim.io/doc/user/lsp.html#vim.lsp.Config) |
| `filetypes` | when to auto-attach | same |
| `root_markers` | workspace root detection (upwards search) | [`:help lsp-root_markers`](https://neovim.io/doc/user/lsp.html#lsp-root_markers) |
| `root_dir` | explicit root, overrides markers | [`:help vim.lsp.Config`](https://neovim.io/doc/user/lsp.html#vim.lsp.Config) |
| `capabilities` | client feature advertisement | [`:help lsp-config`](https://neovim.io/doc/user/lsp.html#lsp-config) |
| `init_options` / `settings` | server-defined config payload | [`:help lsp-config`](https://neovim.io/doc/user/lsp.html#lsp-config) |
| `on_attach`, `on_init`, `handlers` | behavior hooks | [`:help lsp-attach`](https://neovim.io/doc/user/lsp.html#lsp-attach) |

The Quickstart gives a complete `lua_ls` example.
([`:help lsp-quickstart`](https://neovim.io/doc/user/lsp.html#lsp-quickstart))
For `lua_ls`, that is ~15 lines; `nvim-lspconfig`'s
[`lsp/lua_ls.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/lua_ls.lua)
is the same content, maintained for you. For this repo's 10 servers the
hand-rolled version is not worth maintaining.

---

## 2. Dev-shell-only servers via `nix develop` / direnv

### How the binary is found: process `PATH`

- Core spawns `cmd[1]` via `vim.system(cmd, …)` with no env override unless
  `extra_spawn_params.env` is passed; the spawned process inherits Neovim's
  environment, i.e. its `PATH`. A bare name resolves against the `PATH` **of the
  Neovim process at spawn time**.
  ([`runtime/lua/vim/lsp/rpc.lua`](https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/lua/vim/lsp/rpc.lua) `M.start` / `TransportRun:run`)
- If it cannot spawn, the error text is explicit: "The language server is either
  not installed, missing from PATH, or not executable."
  ([`runtime/lua/vim/lsp/_transport.lua`](https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/lua/vim/lsp/_transport.lua))
- `vim.lsp.enable` validates `cmd` with `vim.fn.executable(v[1])` before starting
  and refuses configs whose command is not executable.
  ([`runtime/lua/vim/lsp.lua`](https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/lua/vim/lsp.lua) `validate_cmd` / `can_start`)

### So the flow works if, and only if, nvim *starts* inside the dev shell

`nix develop` provides the "build environment of a derivation", i.e. it sets
environment variables and `PATH` for the shell it spawns; `nix-direnv`'s
`use_flake` runs `nix print-dev-env` and exports that environment into your
interactive shell (cached).
([`nix develop` manual](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-develop.html) — "starts a `bash` shell that provides an interactive build environment"; [nix-direnv README, "use flake"](https://github.com/nix-community/nix-direnv#use-flake) — "calls `nix print-dev-env`")

Consequences:

- **Launched from inside the dev shell** (you `cd` into the project, direnv
  loads, you run `nvim`): `zls`/etc. are on `PATH`, `vim.lsp.enable` sees them
  executable, LSP attaches. Works today for `ziglings`.
- **Launched from outside** (a nvim in another cwd, a GUI launched before
  `cd`, a remote/nvim client, or a session nvim): the dev-shell `PATH` is not
  inherited; the server is "missing from PATH" and `vim.lsp.enable` skips it.
  Because `vim.lsp.enable` snapshots at `FileType` time, a server that was
  skipped does **not** retroactively start unless you re-run enable/restart.
- The guard pattern already in `home/neovim.nix` (`if vim.fn.executable("zls") == 1 then vim.lsp.enable("zls") end`)
  is exactly right for this: absent from `PATH` → silently skip.

### What actually breaks (granularity, sharing)

- **`PATH` is per-process, `filetypes` is per-server.** You cannot scope a
  binary by filetype; all enabled servers see the same `PATH`. Fine here —
  `zls` only claims `zig`/`zir`.
  ([`lsp/zls.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/zls.lua): `cmd={'zls'}, filetypes={'zig','zir'}`)
- **Root detection still needs a marker.** `zls` uses
  `root_markers = { 'zls.json', 'build.zig', '.git' }` and sets
  `workspace_required = false`. ziglings has no `build.zig` but does have `.git`,
  so it roots fine; if you opened a scratch zig file outside any project, the
  `workspace_required=false` avoids a silent skip.
  ([`lsp/zls.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/zls.lua))
- **Version coupling is the real reason dev-shells win here**: the `ziglings`
  flake pins a `zig-overlay` master and pulls `zls` from its own flake because
  "zls is version-coupled to zig".
  (`/home/gl/projects/ziglings/flake.nix`)
- **Client reuse across roots**: a client is reused when name + resolved
  `root_dir` match; switching projects usually spawns a fresh server from the
  then-current `PATH`.
  ([`runtime/lua/vim/lsp.lua`](https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/lua/vim/lsp.lua) `reuse_client_default`)

### Is dev-shell-only "recommended"?

No primary source *recommends* dropping global servers; the guidance is
explicit that servers must be on `PATH` and that lspconfig does not install
them.
([`:help lsp-quickstart`](https://neovim.io/doc/user/lsp.html#lsp-quickstart): "Install language servers using your package manager"; [README troubleshooting](https://github.com/neovim/nvim-lspconfig#troubleshooting): "If the `cmd` is a name … ensure it is on your `$PATH`").

The Nix frameworks *do* support it deliberately:

- **nixvim** exposes `packageFallback` — when true the server package is
  suffixed onto `PATH` "so that local versions of the language server (e.g. from
  a devshell) can override the Nixvim version."
  ([`modules/lsp/servers/server.nix`](https://github.com/nix-community/nixvim/blob/main/modules/lsp/servers/server.nix))
- **nvf** documents exactly this use case: set the server `cmd` to a bare name
  so LSP "will discover LSP servers from `PATH`", with the example comment "Get
  `basedpyright-langserver` from PATH, e.g., a dev shell."
  ([nvf `docs/manual/configuring/languages/lsp.md`](https://github.com/NotAShelf/nvf/blob/main/docs/manual/configuring/languages/lsp.md))

So: dev-shell supply is a supported *override/fallback*, not the recommended
sole source. For this repo the pragmatic split is: global `home/lsp.nix` is the
always-there baseline; the dev shell wins when present because its `PATH`
entry precedes the profile's (dev-shell env is prepended) — and for
correctness, set `packageFallback`-equivalent behavior or use a bare `cmd` so
the bare name resolves to whichever is first on `PATH`.

---

## 3. Generic "auto-register all servers found on PATH"

There is **no core API** for this. `vim.lsp.enable(name)` takes explicit names;
the name must resolve to a config (a runtimepath `lsp/<name>.lua` or a
`vim.lsp.config(name, …)` call).
([`:help vim.lsp.enable()`](https://neovim.io/doc/user/lsp.html#vim.lsp.enable()))

What is available:

- Core can **list** configs (since 0.14 API level, present in this 0.12.5
  runtime): `vim.lsp.get_configs({ filetype = … })` / `vim.lsp.get_configs()`,
  backed by `nvim_get_runtime_file('lsp/*.lua')`.
  ([`runtime/lua/vim/lsp.lua`](https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/lua/vim/lsp.lua) `get_config_names`, `lsp.get_configs`)
- lspconfig's own `:LspStart` with **no args** enables every configured server
  whose `filetypes` match the current buffer — it iterates `vim.lsp.config._configs`.
  ([`plugin/lspconfig.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/plugin/lspconfig.lua))

So the idiomatic minimal "all servers on PATH" is a short loop over discovered
config names, gated on `vim.fn.executable(cmd[1])`:

```lua
for _, name in ipairs(vim.fn.getcompletion('', 'lsp')) do -- or vim.lsp.get_configs()
  local cfg = vim.lsp.config[name]
  if cfg and type(cfg.cmd) == 'table' and vim.fn.executable(cfg.cmd[1]) == 1 then
    vim.lsp.enable(name)
  end
end
```

Caveats, all primary-source backed:

- `vim.lsp.config[name]` **resolves (evaluates) the config file**, and the docs
  warn `get_configs` "May eagerly (prematurely!) evaluate config files."
  ([`runtime/lua/vim/lsp.lua`](https://raw.githubusercontent.com/neovim/neovim@v0.12.5/runtime/lua/vim/lsp.lua))
- A config whose `cmd` is a **function** (e.g. `yamlls`, which even probes
  `node_modules/.bin`) must be started to know its binary; `executable()` cannot
  pre-check it.
  ([`lsp/yamlls.lua`](https://github.com/neovim/nvim-lspconfig/blob/master/lsp/yamlls.lua))
- There is **no helper plugin** in this repo's stack that does PATH-discovery
  better than the loop; nvim/nvf instead let you declare servers and install
  their packages, optionally falling back to `PATH`.

For a Nix-generated init script you can equally generate `vim.lsp.enable({...})`
from the same Nix list that produces the packages — which is what
`home/neovim.nix` already does, just hand-written.

---

## 4. nixvim vs nvf vs hand-rolled `programs.neovim`

### Do they consume a project's devShell/flake?

**No — neither reads a project's `flake.nix`/devShell.** Both are Nix modules
that build a *wrapped* Neovim from *your* Nix configuration (NixOS/Home-Manager
module or standalone flake). They have no mechanism to import another flake's
`devShells`. What they *can* do is let the runtime prefer `PATH` over their
bundled packages:

- **nixvim**: `plugins.lsp.servers.<name>.packageFallback = true` puts the
  server package at the **end** of `PATH`, so a devshell's copy wins; each
  server also has a `cmd` field you can point at a bare name.
  ([`modules/lsp/servers/server.nix`](https://github.com/nix-community/nixvim/blob/main/modules/lsp/servers/server.nix),
  [`plugins/lsp/language-servers/_mk-lsp.nix`](https://github.com/nix-community/nixvim/blob/main/plugins/lsp/language-servers/_mk-lsp.nix))
- **nvf**: override a preset's `cmd` with `lib.mkForce [ "basedpyright-langserver" "--stdio" ]`
  to "discover LSP servers from `PATH`".
  ([nvf `lsp.md`](https://github.com/NotAShelf/nvf/blob/main/docs/manual/configuring/languages/lsp.md))

Both consume only the **user's** Nix config; dev-shell integration is a runtime
`PATH` side effect, identical in kind to what hand-rolled `programs.neovim`
already does with `extraPackages`.

### Config volume for generic LSP wiring

- **nvf** generated Lua from a table is small. Its LSP module emits
  `vim.lsp.config["<name>"] = <table>` per entry plus one
  `vim.lsp.enable(<names>)` — see
  [`modules/neovim/init/lsp.nix`](https://github.com/NotAShelf/nvf/blob/main/modules/neovim/init/lsp.nix).
  The README itself claims "a few lines of Nix".
- **nixvim** splits LSP across a deprecated-but-supported `plugins.lsp` API and
  a newer `lsp.servers` API, with generated per-server options from
  `generated/lspconfig-servers.json` and a `packages.nix` mapping to nixpkgs
  packages.
  ([`plugins/lsp/language-servers/default.nix`](https://github.com/nix-community/nixvim/blob/main/plugins/lsp/language-servers/default.nix),
  [`modules/lsp/servers/default.nix`](https://github.com/nix-community/nixvim/blob/main/modules/lsp/servers/default.nix))
  There is visible churn here: `_mk-lsp.nix` comments say "`plugins.lsp` will be
  dropped entirely in a few months", and the new `lsp.servers` API exists to
  replace it.
- **Hand-rolled** `programs.neovim` + `lspPackages` + `initLua`: the `initLua`
  `vim.lsp.enable({...})` block in `home/neovim.nix` is ~10 lines, and
  `home/lsp.nix` is an 18-line list.

### Tradeoffs

| axis | hand-rolled | nixvim | nvf |
|---|---|---|---|
| concept count | `programs.neovim` only | large module ecosystem (treesitter, UI, LSP APIs, keymaps) | large module ecosystem + DAG (`lib.nvim.dag`) |
| treesitter | you add it | built-in modules | built-in modules |
| startup | stock, minimal | wrapper + generated Lua | wrapper + DAG-ordered Lua |
| churn risk | nixpkgs only | API migration in flight (`plugins.lsp` → `lsp.servers`) | module surface is very wide |
| dev-shell override | `extraPackages` + bare `cmd` (already done) | `packageFallback` | `cmd` with `mkForce` |
| NixOS/HM module | yes (`programs.neovim`) | yes | yes |
| debug surface | small, readable | generated Lua, harder to inspect | `nvf-print-config` helps |

Both frameworks are legitimate; both are far more machinery than this repo's
ponytail ethos wants for "10 servers on `PATH`". See nixvim's own deprecation
comments, and nvf's README ("There are almost no defaults to annoy you" —
i.e. you configure everything, which is the cost).

---

## Recommendation for this repo

**Keep core Neovim + `nvim-lspconfig`; keep the global baseline; add a
dev-shell override.** Do not adopt nixvim or nvf.

Rationale: the current design already gets the two things you actually need —
lspconfig's server data (`lsp/*.lua` via the plugin) and a single shared
package list (`home/lsp.nix`) — for ~10 lines of Lua. A framework adds a module
ecosystem and generated Lua to replace those 10 lines. Dev-shell-only servers
work only when nvim starts inside the dev shell, so the global list must stay as
the fallback.

### Minimal sketch (edits relative to current `home/neovim.nix`)

1. **Baseline stays global** (unchanged): `extraPackages = lspPackages;` and the
   explicit `vim.lsp.enable({...})`. This is the always-available fallback for
   nvim launched outside any dev shell.

2. **Make project servers override the baseline via `PATH` order + a bare `cmd`.**
   Dev-shell env is prepended to `PATH` by direnv/`nix develop`, so a bare
   `cmd[1]` already resolves to the dev-shell binary first when nvim starts
   inside the shell. `zls` is the only project-scoped server today; the existing
   guard is correct:

   ```lua
   -- zls is project-scoped (ziglings flake); attach only when it is on PATH.
   if vim.fn.executable("zls") == 1 then vim.lsp.enable("zls") end
   ```

   No change needed for ziglings. The only gap: a session/remote nvim started
   *outside* the shell won't pick up `zls`. If that matters, run nvim from
   inside the project (`cd` + direnv + `nvim`) — which is the intended flow.

3. **Optional: auto-enable any lspconfig server present on `PATH`**, to shrink
   the hardcoded id list and make dev-shell additions self-registering. Replace
   the explicit `vim.lsp.enable({...})` block with:

   ```lua
   -- lspconfig supplies lsp/*.lua; enable any whose cmd is on PATH.
   -- ponytail: eagerly resolves configs; fine for ~10 servers, switch to an
   -- explicit list if startup cost ever shows.
   for _, name in ipairs(vim.fn.getcompletion('', 'lsp')) do
     local ok, cfg = pcall(function() return vim.lsp.config[name] end)
     if ok and cfg and type(cfg.cmd) == 'table' and vim.fn.executable(cfg.cmd[1]) == 1 then
       vim.lsp.enable(name)
     end
   end
   ```

   This covers `zls` automatically too (no separate guard). Keep the explicit
   list if you prefer determinism over discovery; either is fine at this scale.

4. **If you later want dev-shell *overrides without* editing global packages**,
   the only primitive is `PATH` precedence, which already works. Do not add a
   framework for it.

Keep `home/lsp.nix` as the one declaration routed to zed/opencode/nvim; that
pattern is the repo's whole reason to avoid a framework.
