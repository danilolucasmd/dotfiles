# dbus

User-level D-Bus session service overrides.

Files in `~/.local/share/dbus-1/services/` shadow the ones in
`/usr/share/dbus-1/services/`, because `XDG_DATA_HOME` is searched first. That
makes this the supported way to change how a D-Bus-activated app is launched
(usually to inject an environment variable) without touching `/usr`.

> **Do not put comments in a `.service` file.** dbus' parser rejects the whole
> file and silently falls back to the `/usr/share` one, so the override just
> stops working with no error anywhere. That is why the explanations live in
> this README instead.

Stowed with `--no-folding` (see `install.sh`) so `services/` stays a real
directory — other applications install service files there too.

---

## org.gnome.NautilusPreviewer.service

Forces **sushi** — the previewer Nautilus opens when you press <kbd>Space</kbd>
on a file — to render video with GStreamer's software `gtksink` instead of the
GPU-accelerated `gtkglsink`, which is broken on this machine's NVIDIA driver.

### Symptoms without it

Pressing <kbd>Space</kbd> on any video shows either:

1. A sad-face error, **"Failed to initialize OpenGL with Gtk"**, or
2. (if you only fix stage 1) a **solid dark green** rectangle, correct aspect
   ratio, no picture.

### Cause

Stage 1 — GDK hands GStreamer a wrapped **desktop OpenGL** context, GStreamer
then binds `EGL_OPENGL_ES_API` and tries to create a **GLES** context sharing
with it. NVIDIA refuses the cross-API share:

```
Retrieved Gdk OpenGL context <glwrappedcontext0>
GL_VERSION: 3.2.0 NVIDIA
Bound OpenGL|ES
Could not create OpenGL context: Failed to create a OpenGL context: EGL_BAD_CONTEXT
```

Stage 2 — setting `GST_GL_API=opengl3` makes the APIs match and the context is
created, but every frame is then uniform dark green. That colour is the
signature of an all-zero YUV frame (Y=0, U=0, V=0 → RGB ≈ 0,135,0): the GL
texture is bound and drawn, but the upload never delivers any pixel data.
`gtkglsink` is simply not usable here.

### Fix

`SUSHI_USE_GST_GTKSINK` is sushi's own escape hatch for broken GL drivers —
it is read by `SushiMediaBin` in `libsushi-1.0.so`, not by the JS:

```console
$ strings /usr/lib/sushi/libsushi-1.0.so | grep -i sink
SUSHI_USE_GST_GTKSINK
Using gtkglsink
Could not create gtkglsink
Falling back to gtksink
Detected software GL rasterizer, falling back to gtksink
```

Setting it selects `gtksink`, which renders correctly. This costs no
performance here: `nvcodec` cannot initialise CUDA on this machine
(`gst-inspect-1.0 nvcodec` → *Unable to initialize CUDA library*), so decoding
already falls back to software `avdec_h264` regardless of the sink.

"Open With Video Trimmer" is unaffected — that is a separate app.

### Verifying

Compare the two sinks directly, outside Nautilus:

```sh
V=~/Videos/some-video.mp4
gst-launch-1.0 filesrc location="$V" ! decodebin ! videoconvert ! glsinkbin sink=gtkglsink  # green
gst-launch-1.0 filesrc location="$V" ! decodebin ! videoconvert ! gtksink                   # correct
```

After editing the `.service`, pick up the change and drive the previewer
directly:

```sh
pkill -x org.gnome.Nauti
dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig

dbus-send --session --dest=org.gnome.NautilusPreviewer \
  /org/gnome/NautilusPreviewer org.gnome.NautilusPreviewer2.ShowFile \
  string:"file:///path/to/video.mp4" string:"" boolean:false string:""

# confirm the override actually took effect
tr '\0' '\n' < /proc/$(pgrep -x org.gnome.Nauti)/environ | grep SUSHI
```

Two gotchas: the interface is `org.gnome.NautilusPreviewer2`, not
`...Previewer`; and the process' `comm` is truncated to `org.gnome.Nauti`, so
match that rather than `pkill -f NautilusPreviewer` — the `-f` form also
matches the shell you are typing in and kills it.

### Removing

Delete this file and re-run `stow -D dbus` if a future `gst-plugins-good`
fixes `gtkglsink` on NVIDIA, or if the machine stops using an NVIDIA GPU.
