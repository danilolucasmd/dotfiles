# snapshots

Not a stow package. These are curated `/etc` files that `install.sh` copies
into place, plus the reasoning behind the numbers in them.

They are copied rather than symlinked because snapper rewrites its own config
file whenever anything calls `set-config`, and a symlink would point that write
straight into this repo. `nautilus/dconf.ini` exists for the same class of
reason.

| File | Installed to | Owned by |
| --- | --- | --- |
| `snapper-root` | `/etc/snapper/configs/root` | snapper |
| `snapper-home` | `/etc/snapper/configs/home` | snapper |
| `snap-pac.ini` | `/etc/snap-pac.ini` | snap-pac |
| `limine-snapper-sync.conf` | `/etc/limine-snapper-sync.conf` | limine-snapper-sync |
| `limine-entry-tool.conf` | `/etc/limine-entry-tool.conf` | limine-entry-tool |

`limine-entry-tool.conf` is a template: `install.sh` substitutes `@@CMDLINE@@`
with a command line built from the running machine. Nothing machine-specific is
committed here — not the filesystem UUID, not the username. `ALLOW_USERS` is
likewise left empty in the snapper configs and set afterwards with
`snapper set-config`.

`/etc/mkinitcpio.conf.d/btrfs-snapshots.conf` has no file here at all. It is
generated from whatever `HOOKS` the machine already has, so that it composes
with the rest of that line instead of overwriting it. Writing it is only half
the job — `install.sh` runs `mkinitcpio -P` afterwards, because the running
initramfs keeps whatever hooks it was born with.

## The snapperd trap

Do not apply these snapper configs by copying the file and then calling
`snapper set-config` for the parts that vary per machine. snapperd caches every
config in memory, and `set-config` writes the *whole file* back from that
cache — so the copy is silently reverted and only the key you just set
survives. It looks like it worked; `get-config` then shows stock values for
everything else.

`install.sh` therefore stops snapperd first (it is dbus-activated, so the next
snapper call brings it straight back, reading from disk) and substitutes
`@@ALLOW_USERS@@` into the file before writing it. One write, no second party.

## Why Limine and not GRUB

This repo used to install `grub-btrfs`, and on an archinstall layout that never
worked: archinstall's default bootloader is systemd-boot, so `grub-btrfsd`
faithfully regenerated a `grub.cfg` that nothing read.

Fixing it by installing GRUB properly would have fixed the smaller half of the
problem. The larger half is that **archinstall mounts the ESP at `/boot`**, so
`vmlinuz-linux` and `initramfs-linux.img` live on a FAT32 partition, outside
every btrfs snapshot. Booting a snapshot from a GRUB menu gets you the old
root subvolume paired with *today's* kernel, against an old
`/usr/lib/modules/<version>` that no longer matches it.

`limine-snapper-sync` is the piece that closes that: it copies each snapshot's
kernel and initramfs onto the ESP when the snapshot is created, deduplicated by
hash so snapshots sharing a kernel cost nothing extra. Booting a snapshot boots
the kernel it was taken with. This is also what omarchy does, which is where
the idea came from.

## The ESP budget

This is the constraint that shapes every number in `limine-snapper-sync.conf`,
and it is not specific to one machine: archinstall's best-effort partition
layout produces a **1 GiB ESP**, and upstream recommends 4 GiB.

Measured on the machine this was written for, before any of it was tuned:

```
$ lsinitcpio -a /boot/initramfs-linux.img
==> Early CPIO: 107.57 MiB
==> Size: 11.44 MiB
```

Almost all of that 107 MiB is `/usr/lib/firmware/nvidia/*/gsp/*` — nouveau's
GSP firmware for every Ada chip — pulled in by the `kms` hook because
autodetect sees an NVIDIA card. The machine runs the proprietary driver
(`nvidia_drm`, from `nvidia-open-dkms`), so none of it is ever loaded.

Dropping `kms` takes a kernel generation from ~157 MiB to ~43 MiB, which is the
difference between about five and about twenty of them fitting in the 75% of
1 GiB that `LIMIT_USAGE_PERCENT` allows. Snapshot *count* is not the budget —
snapshots sharing a kernel are free — distinct kernels are.

`install.sh` therefore drops `kms` **only when an NVIDIA driver is installed**.
On amdgpu or Intel, early KMS is worth having and the firmware is a fraction of
the size, so the hook stays.

The cost on NVIDIA is that the console runs on the EFI framebuffer until
`nvidia_drm` loads at the udev stage. That is the normal arrangement for the
proprietary driver.

`/boot/intel-ucode.img` (15 MiB) is unreferenced — the `microcode` hook embeds
microcode in the early CPIO already — and is free to delete if the partition
ever gets tight.

## What happens when the budget is exceeded

Nothing visible, which is the dangerous part. Past `LIMIT_USAGE_PERCENT`,
snapper keeps taking snapshots and they simply stop getting boot entries.
`ENABLE_NOTIFICATION=yes` and the check in `snapshot` after every create both
exist to make that audible.

`limine-snapper-remove <id>..<id>` frees entries when it happens.

## Retention

`snapper-root` turns the timeline **off**. snap-pac already snapshots every
pacman transaction and `snapshot` covers everything else worth returning to; an
hourly snapshot of `/` in between captures nothing but still wants a boot entry
and a kernel copy.

`snapper-home` turns it **on**, at ten hourly / seven daily / four weekly.
These never become boot entries, so they cost no ESP space at all, and they are
the only thing standing between a mistaken `rm` and a lost afternoon.

`snap-pac.ini` marks kernel, graphics, systemd and bootloader transactions
`important=yes` so they are retained under `NUMBER_LIMIT_IMPORTANT` rather than
aged out by a run of routine installs. It does this by **package name**, not by
command, because snap-pac matches the parent command line exactly and `yay`
builds an argument list nothing would predict.

## A snapshot is not a backup

Everything here lives on the same filesystem on the same disk. It survives a
bad `-Syu`, a botched `/etc` edit and an `rm` in the wrong directory. It
survives none of a dead NVMe. Off-machine backup is a separate concern and
deliberately not this repo's.
