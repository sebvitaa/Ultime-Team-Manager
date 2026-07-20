# Fixing the Linux build failure (`clang: error: linker command failed`)

## TL;DR

Flutter is installed via **snap**. The snap ships its own old linker and C
library (Ubuntu 20.04 base → **glibc 2.31**). Your machine runs **glibc 2.39**.
When linking the Linux desktop app, the snap's old `ld` is forced to link
against your host's *newer* system libraries (pulled in by the `audioplayers`
plugin), and it cannot resolve their newer symbol versions. The link aborts.

**The build isn't broken — the toolchain is mismatched. Fix it by not using
snap Flutter for Linux desktop, or by not targeting Linux desktop.**

---

## The actual error

`flutter run -v` shows the linker step failing with a long list of
`undefined reference` errors like:

```
/snap/flutter/current/usr/bin/ld: /lib/x86_64-linux-gnu/libdw.so.1:        undefined reference to `dlopen@GLIBC_2.34'
/snap/flutter/current/usr/bin/ld: /lib/x86_64-linux-gnu/libgstreamer-1.0.so.0: undefined reference to `__isoc23_strtol@GLIBC_2.38'
/snap/flutter/current/usr/bin/ld: /lib/x86_64-linux-gnu/libunwind.so.8:     undefined reference to `stat@GLIBC_2.33'
/snap/flutter/current/usr/bin/ld: /lib/x86_64-linux-gnu/libzstd.so.1:       undefined reference to `pthread_create@GLIBC_2.34'
...
clang: error: linker command failed with exit code 1
```

The short message you saw (`clang: error: linker command failed`) is just the
tail of this.

---

## Why it happens (root cause)

| Piece | Value on this machine |
| ----- | --------------------- |
| Flutter install | **snap** → `/home/joaquin/snap/flutter/common/flutter` |
| snap bundled linker | `/snap/flutter/current/usr/bin/ld` (Ubuntu 20.04, glibc 2.31) |
| Host glibc | **2.39** (`ldd --version`) |
| Plugin pulling in the bad libs | `audioplayers: ^6.8.1` |

`audioplayers_linux` links against **GStreamer**, which in turn drags in host
system libraries (`libgstreamer`, `libdw`, `libunwind`, `libzstd`, …). Those
host libraries were compiled against **glibc 2.33 / 2.34 / 2.38** and export
symbols with those version tags.

The snap's bundled linker only knows about **glibc 2.31** symbols, so every
`...@GLIBC_2.34` / `@GLIBC_2.38` reference is "undefined" to it. Link fails.

This is a well-known incompatibility between **snap Flutter** and **modern
Ubuntu (22.04 / 24.04)** — not a bug in your code.

---

## Fix (recommended): install Flutter from the official tarball instead of snap

Using a non-snap Flutter makes the build use your host's own consistent
toolchain (clang / ld / glibc 2.39), so all the symbol versions match.

```bash
# 1. Remove the snap version
sudo snap remove flutter

# 2. Install the git/tarball version
sudo apt-get update
sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa \
     clang cmake ninja-build pkg-config libgtk-3-dev

git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter

# 3. Put it on PATH (add to ~/.bashrc so it persists)
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Verify the RIGHT flutter is picked up (should NOT contain "snap")
which flutter
flutter doctor -v
```

Then rebuild cleanly:

```bash
cd ~/universidad/ramos/taller-app-web/Ultime-Team-Manager
flutter clean
flutter pub get
flutter run -d linux
```

> After switching, confirm `which flutter` points at
> `~/development/flutter/bin/flutter` and **not** `~/snap/...`. If it still
> shows snap, open a new terminal or re-run `source ~/.bashrc`.

---

## Alternative fixes

### Option A — Just run on a different target (fastest, no reinstall)

If you don't specifically need the Linux desktop build, this app is a Flutter
app and runs elsewhere without the GStreamer/snap-linker problem:

```bash
flutter run -d chrome     # web
# or
flutter run -d <android-device-id>
flutter devices           # list what's available
```

The linker error is Linux-desktop-only; the same code compiles fine for
web/Android/mobile.

### Option B — Remove/replace the audioplayers dependency (only if you don't need audio on Linux)

The linker failure is triggered by `audioplayers_linux` → GStreamer. If audio
playback isn't needed on the Linux desktop target, removing `audioplayers`
from `pubspec.yaml` (or swapping for a package without a GStreamer Linux
backend) makes the link succeed even under snap Flutter. This changes app
functionality, so only do it if audio on Linux is genuinely optional.

### Option C — Use the Flutter APT package (Ubuntu)

Same idea as the tarball route — any non-snap Flutter that uses the host
toolchain works. The official tarball (recommended fix above) is the
best-supported path.

---

## How to confirm it's fixed

```bash
which flutter                 # must NOT contain "snap"
ldd --version | head -1       # host glibc (2.39 here)
flutter clean && flutter run -d linux
```

A successful build links `intermediates_do_not_run/contador_app` with **no
`undefined reference` lines** and launches the app window.

---

## Why NOT to "just fix the linker flags"

Tempting workarounds like forcing `-lc`, symlinking host libs into the snap,
or setting `LD_LIBRARY_PATH` don't hold: you'd be mixing glibc 2.31 and 2.39
runtime objects, which produces crashes or ABI corruption at runtime even if
the link somehow succeeds. Use a toolchain that is internally consistent —
that's the tarball/APT Flutter, not snap, on modern Ubuntu.
