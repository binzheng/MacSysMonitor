#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/MacSysMonitor.xcodeproj"
SCHEME="MacSysMonitor"
DERIVED_DATA="$ROOT/build"
STAGING="$ROOT/dist/dmg_root"
DMG_PATH="$ROOT/dist/MacSysMonitor.dmg"
VOL_NAME="MacSysMonitor"

generate_instruction_image() {
  local out="$1"
  OUT_PATH="$out" python3 - <<'PY'
import math, struct, zlib, os
w, h = 900, 520
out_path = os.environ["OUT_PATH"]
bg0 = (8, 16, 32)
bg1 = (20, 120, 200)
buf = bytearray()
for y in range(h):
    t = y / (h - 1)
    r = int(bg0[0] + (bg1[0] - bg0[0]) * t)
    g = int(bg0[1] + (bg1[1] - bg0[1]) * t)
    b = int(bg0[2] + (bg1[2] - bg0[2]) * t)
    buf.extend(bytes([r, g, b, 255]) * w)

def put(px, x, y, color):
    if 0 <= x < w and 0 <= y < h:
        idx = (y * w + x) * 4
        for i,c in enumerate(color):
            buf[idx+i] = c

def line(x0,y0,x1,y1,color,thick=3):
    dx, dy = x1 - x0, y1 - y0
    steps = int(max(abs(dx), abs(dy)))
    for i in range(steps+1):
        x = int(x0 + dx * i / steps)
        y = int(y0 + dy * i / steps)
        for ix in range(-thick, thick+1):
            for iy in range(-thick, thick+1):
                put(buf, x+ix, y+iy, color)

def rect(x0,y0,x1,y1,color):
    for y in range(y0,y1):
        for x in range(x0,x1):
            put(buf,x,y,color)

# arrow pointing from left icon (200,260) to Applications (600,260)
arrow_y = int(h*0.55)
arrow_color = (255, 220, 140, 255)
line(int(w*0.22), arrow_y, int(w*0.70), arrow_y, arrow_color, 14)
line(int(w*0.70), arrow_y, int(w*0.62), arrow_y-40, arrow_color, 14)
line(int(w*0.70), arrow_y, int(w*0.62), arrow_y+40, arrow_color, 14)
rect(int(w*0.70), arrow_y-40, int(w*0.80), arrow_y+40, (30, 210, 255, 200))

# simple 5x7 font
font = {
    'A':(0x1E,0x05,0x05,0x1E), 'D':(0x1F,0x11,0x0A,0x04),
    'G':(0x0E,0x11,0x15,0x07), 'R':(0x1F,0x05,0x0D,0x13),
    'O':(0x0E,0x11,0x11,0x0E), 'P':(0x1F,0x05,0x05,0x02),
    ' ':(0,0,0,0), 'T':(0x01,0x1F,0x01,0x01), 'L':(0x1F,0x10,0x10,0x10),
    'C':(0x0E,0x11,0x11,0x0A), 'I':(0x11,0x1F,0x11,0x00), 'N':(0x1F,0x02,0x04,0x1F),
    'S':(0x12,0x15,0x15,0x09), 'E':(0x1F,0x15,0x15,0x11), 'M':(0x1F,0x02,0x04,0x02,0x1F),
    'U':(0x0F,0x10,0x10,0x0F), ':':(0x00,0x0A,0x00,0x00)
}

def draw_text(text, x, y, scale=6, color=(240,240,255,255)):
    cursor = x
    for ch in text:
        glyph = font.get(ch.upper(), font[' '])
        width = len(glyph)
        for col, bits in enumerate(glyph):
            for row in range(7):
                if bits & (1 << row):
                    for sx in range(scale):
                        for sy in range(scale):
                            put(buf, cursor + (col*scale)+sx, y + (row*scale)+sy, color)
        cursor += (width+1)*scale

draw_text("DRAG   TO   APPLICATIONS", 120, 90, scale=8, color=(255,245,210,255))
draw_text("MacSysMonitor.app を Applications へドラッグ＆ドロップ", 70, 260, scale=5, color=(220,240,255,255))
draw_text("※ アプリを左から右へ移動してください", 120, 330, scale=4, color=(200,230,255,255))

png = b'\x89PNG\r\n\x1a\n'
def chunk(tp,data): return struct.pack('>I',len(data))+tp+data+struct.pack('>I', zlib.crc32(tp+data)&0xffffffff)
raw = bytearray()
for y in range(h):
    raw.append(0)
    raw.extend(buf[y*w*4:(y+1)*w*4])
comp = zlib.compress(bytes(raw), 9)
png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', comp)
png += chunk(b'IEND', b'')
open(out_path,"wb").write(png)
PY
}

set_finder_layout() {
  local folder="$1"
  local bg_image="$2"
  # Use AppleScript to set icon view, background, and positions. Requires Finder access.
  osascript <<'APPLESCRIPT' "$folder" "$bg_image"
on run argv
	set theFolder to POSIX file (item 1 of argv) as alias
	set bgFile to POSIX file (item 2 of argv) as alias
	tell application "Finder"
		open theFolder
		delay 0.2
		tell container window of theFolder
			set current view to icon view
			set toolbar visible to false
			set statusbar visible to false
			set bounds to {100, 100, 900, 600}
		end tell
		tell icon view options of theFolder
			set arrangement to not arranged
			set icon size to 110
			set background picture to bgFile
		end tell
		try
			set position of item "MacSysMonitor.app" of theFolder to {160, 260}
		end try
		try
			set position of item "Applications" of theFolder to {560, 260}
		end try
		delay 0.3
		update theFolder
	end tell
end run
APPLESCRIPT
}

echo "==> Building Release..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA"

APP="$DERIVED_DATA/Build/Products/Release/MacSysMonitor.app"
if [[ ! -d "$APP" ]]; then
  echo "App bundle not found at $APP" >&2
  exit 1
fi

echo "==> Preparing staging at $STAGING"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING"/
ln -s /Applications "$STAGING/Applications"
mkdir -p "$STAGING/.background"
BG_IMG="$STAGING/.background/DragToApplications.png"
OUT_PATH="$BG_IMG" generate_instruction_image "$BG_IMG"
cp "$BG_IMG" "$STAGING/DragToApplications.png"
set_finder_layout "$STAGING" "$BG_IMG" || true
PUBLIC_BG="$ROOT/dist/DragToApplications.png"
cp "$BG_IMG" "$PUBLIC_BG"

echo "==> Creating DMG with create-dmg"
mkdir -p "$ROOT/dist"
rm -f "$DMG_PATH"
BG_USE="$PUBLIC_BG"
create-dmg \
  --volname "$VOL_NAME" \
  --volicon "$ROOT/MacSysMonitor/AppIcon.icns" \
  --background "$BG_USE" \
  --window-pos 200 120 \
  --window-size 800 420 \
  --icon-size 110 \
  --icon "MacSysMonitor.app" 200 260 \
  --app-drop-link 600 260 \
  "$DMG_PATH" \
  "$APP"

echo "Done: $DMG_PATH"
