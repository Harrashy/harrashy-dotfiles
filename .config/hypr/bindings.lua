-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
-- # Application bindings

-- Application bindings

-- 1. Unbind the default system bindings first
hl.unbind("SUPER + RETURN")
hl.unbind("SUPER + ALT + RETURN")

-- Application bindings
hl.bind(
	"SUPER + RETURN",
	hl.dsp.exec_cmd('uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"'),
	{ description = "Terminal" }
)
hl.bind("SUPER + B", hl.dsp.exec_cmd("google-chrome-stable"), { description = "Browser" })
hl.bind("SUPER + D", hl.dsp.exec_cmd("flatpak run com.discordapp.Discord"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("flatpak run com.valvesoftware.Steam"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("flatpak run com.spotify.Client"))
hl.bind("SUPER + Z", hl.dsp.exec_cmd("flatpak run com.rtosta.zapzap"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("flatpak run io.ente.auth"))
hl.bind("SUPER + SHIFT + ALT + M", hl.dsp.exec_cmd("omarchy-launch-or-focus-tui cliamp"), { description = "Music TUI" })
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("omarchy-launch-editor"), { description = "Editor" })
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("omarchy-launch-tui lazydocker"), { description = "Docker" })
hl.bind(
	"SUPER + SHIFT + L",
	hl.dsp.exec_cmd('omarchy-launch-or-focus ^localsend$ "uwsm-app -- localsend"'),
	{ description = "LocalSend" }
)

-- If your web app url contains #, you no longer need to escape it as ## in Lua

hl.bind(
	"SUPER + SHIFT + C",
	hl.dsp.exec_cmd('omarchy-launch-webapp "https://calendar.google.com/calendar/u/0/r"'),
	{ description = "Calendar" }
)
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd('omarchy-launch-webapp "https://app.hey.com"'), { description = "Email" })
hl.bind(
	"SUPER + Y",
	hl.dsp.exec_cmd('omarchy-launch-webapp "https://youtube.com/"'),
	{ description = "YouTube" }
)

hl.bind(
	"SUPER + G",
	hl.dsp.exec_cmd('omarchy-launch-or-focus-webapp "Google Messages" "https://messages.google.com/web/conversations"'),
	{ description = "Google Messages" }
)
hl.bind(
	"SUPER + SHIFT + P",
	hl.dsp.exec_cmd('omarchy-launch-or-focus-webapp "Google Photos" "https://photos.google.com/"'),
	{ description = "Google Photos" }
)
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("omarchy-launch-tui btop"), { description = "btop" })
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd('omarchy-launch-webapp "https://x.com/"'), { description = "X" })
hl.bind(
	"SUPER + X",
	hl.dsp.exec_cmd('omarchy-launch-webapp "https://x.com/home"'),
	{ description = "X" }
)

-- Add extra bindings
-- hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("alacritty -e ssh your-server"))


-- Overwrite existing bindings, like putting Omarchy Menu on Super + Space
-- hl.unbind("SUPER + SPACE")
-- hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("omarchy-menu"), { description = "Omarchy menu" })
hl.unbind("SUPER + F")
hl.bind("SUPER + F", hl.dsp.exec_cmd("uwsm app -- nautilus"), { description = "File manager" })
hl.bind("SUPER + A", hl.dsp.exec_cmd("omarchy agent"), { description = "Open agent window" })
hl.bind("SUPER + U", hl.dsp.exec_cmd("gnome-boxes"), { description = "Boxes" })
o.bind("SUPER + I", "Shell Settings", "omarchy-shell shell toggle shell.settings")
hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.exec_cmd("omarchy launch about"), { description = "About" })
hl.bind("SUPER + H", hl.dsp.exec_cmd("/home/harrashy/AppImages/hydra.appimage --no-sandbox"), { description = "Hydra" })
hl.bind("SUPER + SHIFT + K", hl.dsp.exec_cmd("omarchy-menu toggle power"), { description = "Power menu" })

-- qylock (clockwork/tape) lockscreen replaces the default system lock
hl.unbind("SUPER + CTRL + L")
hl.bind(
	"SUPER + CTRL + L",
	hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/share/quickshell-lockscreen/lock.sh"),
	{ description = "Lock system (qylock)" }
)



