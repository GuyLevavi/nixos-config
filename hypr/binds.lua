-- `noctalia msg` verbs are the v5 CLI; panel ids are free-form
-- (`noctalia msg panel-toggle --help` lists them).

local mod = "SUPER"
local function key(mods, k) return mods == "" and k or mods .. " + " .. k end
local function exec(mods, k, cmd, opts) hl.bind(key(mods, k), hl.dsp.exec_cmd(cmd), opts) end
local function noctalia(mods, k, verb, opts) exec(mods, k, "noctalia msg " .. verb, opts) end

-- ------------------------------------------------------------------- shell ---
noctalia(mod, "Space", "panel-toggle launcher")
noctalia(mod, "V", "panel-toggle clipboard")
noctalia(mod, "N", "panel-toggle control-center")
noctalia(mod, "S", "settings-toggle")
noctalia(mod, "Tab", "window-switcher")
noctalia(mod, "L", "session lock")
noctalia(mod .. " + SHIFT", "E", "panel-toggle session")

-- Emoji: open the launcher and type the emoji prefix.

-- ------------------------------------------------------------------- theme ---
noctalia(mod, "T", "settings-open") -- pick a palette in the GUI
noctalia(mod .. " + SHIFT", "T", "theme-mode-toggle") -- dark <-> light
noctalia(mod, "W", "wallpaper-next")

-- -------------------------------------------------------------- screenshot ---
noctalia("", "Print", "screenshot-region")
noctalia("SHIFT", "Print", "screenshot-fullscreen pick")
exec(mod, "Print", "screen-record")

-- --------------------------------------------------------------- launchers ---
exec(mod, "Return", "ghostty")
exec(mod, "B", "firefox")
exec(mod, "E", "nautilus")
exec(mod, "Z", "zeditor")

-- ------------------------------------------------------------------ windows ---
hl.bind(key(mod, "Q"), hl.dsp.window.close())
hl.bind(key(mod, "F"), hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(key(mod, "G"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(key(mod, "P"), hl.dsp.window.pseudo())
hl.bind(key(mod, "J"), hl.dsp.layout("togglesplit"))

hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(key(mod, dir), hl.dsp.focus({ direction = dir }))
    hl.bind(key(mod .. " + SHIFT", dir), hl.dsp.window.move({ direction = dir }))
end

hl.bind(key(mod, "mouse:272"), hl.dsp.window.drag(), { mouse = true })
hl.bind(key(mod, "mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- --------------------------------------------------------------- workspaces ---
for i = 1, 5 do
    hl.bind(key(mod, i), hl.dsp.focus({ workspace = i }))
    hl.bind(key(mod .. " + SHIFT", i), hl.dsp.window.move({ workspace = i }))
end

hl.bind(key(mod, "mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key(mod, "mouse_up"), hl.dsp.focus({ workspace = "e-1" }))

-- ------------------------------------------------------------------- media ---
-- locked fires even on the lock screen; repeating = held-key repeat.
local locked = { locked = true }
local held = { locked = true, repeating = true }
noctalia("", "XF86AudioMute", "volume-mute", locked)
noctalia("", "XF86AudioMicMute", "mic-mute", locked)
noctalia("", "XF86AudioRaiseVolume", "volume-up", held)
noctalia("", "XF86AudioLowerVolume", "volume-down", held)
noctalia("", "XF86MonBrightnessUp", "brightness-up", held)
noctalia("", "XF86MonBrightnessDown", "brightness-down", held)

noctalia("", "XF86AudioPlay", "media toggle", locked)
noctalia("", "XF86AudioNext", "media next", locked)
noctalia("", "XF86AudioPrev", "media previous", locked)

-- ------------------------------------------------------------------ toggles ---
noctalia(mod, "F1", "wifi-toggle")
noctalia(mod, "F2", "bluetooth-toggle")
noctalia(mod, "F3", "nightlight-toggle")
noctalia(mod, "F4", "caffeine-toggle")
noctalia(mod, "F5", "notification-dnd-toggle")
noctalia(mod, "F6", "bar-toggle")
