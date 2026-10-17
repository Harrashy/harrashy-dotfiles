#!/usr/bin/env bash
# Omarchy theme-set hook: tint the file manager's folder icons to the theme.
#
# Reads the active theme's icons.theme variant (e.g. Yaru-magenta) and recolors
# its folder icons, in the theme's selection color, into the user icon theme
# "Omarchy-Accent" (which inherits the variant for every other icon) and selects
# it. Runs on every theme change so the folder color always matches the theme.

source "${THPM_THEME_ENV:-$HOME/.local/share/thpm/lib/theme-env.sh}"

: "${selection_background:=$normal_blue}"

command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$THPM_CURRENT_THEME_DIR" "$selection_background" <<'PYEOF'
import os, sys, re, glob, shutil, subprocess, concurrent.futures

theme_dir, target = sys.argv[1], sys.argv[2].lstrip('#')
home = os.path.expanduser('~')
name = 'Omarchy-Accent'
dest = os.path.join(home, '.local/share/icons', name)

MAGICK = shutil.which('magick') or shutil.which('convert')
if not MAGICK:
    sys.exit('imagemagick not found')


def read_variant():
    conf = os.path.join(theme_dir, 'icons.theme')
    if os.path.isfile(conf):
        lines = open(conf).read().strip().splitlines()
        if lines and lines[0].strip():
            return lines[0].strip()
    return 'Yaru-blue'


variant = read_variant()
src = os.path.join('/usr/share/icons', variant)
if not os.path.isdir(src):
    variant, src = 'Yaru', '/usr/share/icons/Yaru'
if not os.path.isdir(src):
    sys.exit('no source icon theme')


def rgb2hsl(r, g, b):
    r, g, b = r / 255, g / 255, b / 255
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    l = (mx + mn) / 2
    if d == 0:
        return 0.0, 0.0, l
    s = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = ((g - b) / d) % 6
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return h * 60, s, l


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def dominant(path):
    out = subprocess.run([MAGICK, path, '-alpha', 'remove', '-colors', '4',
                          '-format', '%c', 'histogram:info:-'],
                         capture_output=True, text=True).stdout
    best, bestn = '000000', -1
    for line in out.splitlines():
        m = re.search(r'(\d+):.*#([0-9A-Fa-f]{6})', line)
        if m and int(m.group(1)) > bestn:
            bestn, best = int(m.group(1)), m.group(2)
    return hex2rgb(best)


tH, tS, tL = rgb2hsl(*hex2rgb(target))

base_file = os.path.join(src, '256x256/places/folder.png')
if not os.path.isfile(base_file):
    for p in glob.glob(os.path.join(src, '**/*folder*.png'), recursive=True):
        base_file = p
        break
sH, sS, sL = rgb2hsl(*dominant(base_file))

Hpct = tH / 360.0 * 100.0
Spct = tS * 100.0
Lpct = (tL / sL * 100.0) if sL else 100.0


def recolor(srcf, dstf, lval):
    os.makedirs(os.path.dirname(dstf), exist_ok=True)
    subprocess.run([MAGICK, srcf, '-colorspace', 'HSL',
                    '-channel', 'R', '-evaluate', 'set', '%.3f%%' % Hpct,
                    '-channel', 'G', '-evaluate', 'set', '%.3f%%' % Spct,
                    '+channel', '-colorspace', 'sRGB',
                    '-modulate', '%.3f,100,100' % lval, dstf],
                   check=True, stderr=subprocess.DEVNULL)


tmp = os.path.join('/tmp', 'omarchy-accent-cal.png')
for _ in range(3):
    recolor(base_file, tmp, Lpct)
    rL = rgb2hsl(*dominant(tmp))[2]
    if rL <= 0.001 or abs(tL - rL) < 0.008:
        break
    Lpct *= tL / rL

files = [p for p in glob.glob(os.path.join(src, '**/*.png'), recursive=True)
         if 'folder' in os.path.basename(p).lower()]

stamp = os.path.join(dest, '.stamp')
want = '%s\n%s\n' % (variant, target)
if not (os.path.isfile(stamp) and open(stamp).read() == want):
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)

    def work(p):
        recolor(p, os.path.join(dest, os.path.relpath(p, src)), Lpct)

    with concurrent.futures.ThreadPoolExecutor(max_workers=(os.cpu_count() or 4)) as ex:
        list(ex.map(work, files))

    dirs = sorted({os.path.dirname(os.path.relpath(p, src)) for p in files})
    ctxmap = {'places': 'Places', 'actions': 'Actions', 'status': 'Status',
              'apps': 'Applications', 'emblems': 'Emblems', 'devices': 'Devices'}
    lines = ['[Icon Theme]', 'Name=%s' % name,
             'Comment=Yaru folder icons tinted to the Omarchy theme accent',
             'Inherits=%s' % variant, 'Example=folder',
             'Directories=' + ','.join(dirs), '']
    for d in dirs:
        m = re.match(r'(\d+)x\1(@2x)?', d)
        size = m.group(1) if m else '48'
        scale = 2 if '@2x' in d.split('/')[0] else 1
        ctx = ctxmap.get(os.path.basename(d), 'Places')
        lines += ['[%s]' % d, 'Size=%s' % size, 'Scale=%d' % scale,
                  'Context=%s' % ctx, 'Type=Fixed', '']
    open(os.path.join(dest, 'index.theme'), 'w').write('\n'.join(lines) + '\n')
    open(stamp, 'w').write(want)

cache = shutil.which('gtk-update-icon-cache')
if cache:
    subprocess.run([cache, '-f', '-t', dest], stderr=subprocess.DEVNULL)
PYEOF

icon_theme="Omarchy-Accent"
if [[ -d "$HOME/.local/share/icons/$icon_theme" ]]; then
    bus="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
    DBUS_SESSION_BUS_ADDRESS="$bus" gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true
fi
