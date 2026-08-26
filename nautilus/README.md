# nautilus

Nautilus' sidebar bookmarks and the handful of preferences that make it open
folders the way this desktop expects. The package covers two very different
kinds of state, which is the only interesting thing about it.

## The bookmarks are a file, so they are stowed

`.config/gtk-3.0/bookmarks` is the list that fills the left sidebar. It is a
plain text file, one `file:///path Label` per line, and despite the `gtk-3.0`
in the path it is still where GTK 4 -- and therefore current Nautilus -- reads
bookmarks from. The GTK Open/Save dialogs read the same file, which is why
bookmarking a folder in Nautilus makes it appear in every app's save dialog.

Because it is a file it is a normal stow symlink, and it stays live in both
directions: GTK rewrites bookmarks through GLib's replace-in-place, which
follows the symlink instead of clobbering it, so **adding or reordering a
bookmark in the Nautilus sidebar shows up as a diff in this repo**. Nothing has
to be copied back by hand. Verified rather than assumed -- a replace through
the symlink leaves the link intact and lands the new content in the repo.

The paths are absolute and name this user, `/home/danilolucasmd/...`, which is
already true of `install.sh` and the git config, so it is consistent with the
rest of the repo rather than a new assumption. A different username on a fresh
machine would need them rewritten.

## The preferences are a database, so they are loaded

Everything else Nautilus remembers lives in dconf, a single binary database
under `~/.config/dconf/user`. It cannot be a symlink -- it is not per-app, the
whole desktop shares it, and it is rewritten as a unit. So `dconf.ini` holds
the settings as a keyfile and `install.sh` applies them:

    dconf load / < nautilus/dconf.ini

`dconf load` merges, so this writes the listed keys and leaves the rest of the
database untouched. It is safe to re-run, and re-running it is how you undo a
preference you changed by accident in the UI.

`dconf.ini` is hand-curated, not a dump: it carries only keys that differ from
the GSettings schema defaults, and the file's own comments say what was left
out and why. To find out whether a setting you just changed is worth adding,
compare it against its schema default -- the memory backend reports the default
without touching the real database:

    gsettings get org.gnome.nautilus.preferences default-folder-viewer
    GSETTINGS_BACKEND=memory gsettings get org.gnome.nautilus.preferences default-folder-viewer

If those two disagree, the key is a decision and belongs in `dconf.ini`. If
they agree, it is just the default and adding it is noise. `dconf dump
/org/gnome/nautilus/` shows everything Nautilus has stored, most of which is
window geometry.

## Stowed `--no-folding`

`~/.config/gtk-3.0` stays a real directory. Folding it into a single symlink
would put the whole GTK 3 config directory inside this repo, and that directory
is written to by things other than this package -- theme tools such as
`nwg-look` drop a `settings.ini` in there. As with the other `--no-folding`
packages, **a new file added here is not live until `stow --no-folding
nautilus` runs again.**

`dconf.ini` sits at the package root and must not be stowed into `$HOME`, so
the stow call in `install.sh` passes `--ignore='^dconf\.ini$'`. That adds to
stow's built-in ignore list rather than replacing it, which is why this
`README.md` still needs no special handling -- the built-in list already skips
`^/README.*`.

Note the missing leading slash, which is not a typo and is worth knowing before
writing another one of these: stow matches a `--ignore` regex against the path
relative to the package with **no** leading slash, while the patterns in its
built-in list and in a `.stow-local-ignore` file are matched against the same
path **with** one. `--ignore='^/dconf\.ini$'` looks right, is accepted without
complaint, and silently matches nothing.

## See also

`dbus/README.md` -- the other half of the Nautilus setup, a D-Bus activation
override that makes the spacebar quick preview (sushi) work on NVIDIA.
