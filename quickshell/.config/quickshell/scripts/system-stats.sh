#!/bin/bash
# Quickshell module: one reading of what the machine is doing right now —
# processor, graphics, memory and the root filesystem's disk.
#
# Prints one line of JSON, consumed by the performance panel's JsonScript.
#
# Counters come out raw. /proc/stat and /proc/diskstats are cumulative since
# boot, so a percentage or a transfer rate is a difference between two
# readings — which is the caller's job, holding the previous sample and
# dividing, exactly as the network panel does with /proc/net/dev. Measuring in
# here would mean sleeping inside every poll, and this one runs on the bar's
# schedule whether the panel is up or not.
#
# Nothing here is allowed to be slow or to need root: sysfs reads, one
# nvidia-smi (~30 ms) and one df. Everything that can be missing — a machine
# with no discrete GPU, no cpufreq, no readable temperature — comes back null
# rather than failing the whole reading.

set -uo pipefail

# The hwmon numbering is not stable across boots — hwmon3 is coretemp today
# and need not be tomorrow — so every sensor is found by the name the driver
# registers rather than by a path.
hwmon_for() {
	local want d name
	for want in "$@"; do
		for d in /sys/class/hwmon/hwmon*; do
			read -r name <"$d/name" 2>/dev/null || continue
			if [ "$name" = "$want" ]; then
				printf '%s' "$d"
				return 0
			fi
		done
	done
	return 1
}

# millidegrees from a hwmon input file, as whole degrees with one decimal.
temp_from() {
	local path=$1 raw
	[ -r "$path" ] || return 1
	read -r raw <"$path" 2>/dev/null || return 1
	[ -n "$raw" ] || return 1
	awk -v m="$raw" 'BEGIN { printf "%.1f", m / 1000 }'
}

t=$(date +%s.%N)
read -r uptime _ </proc/uptime

############################################################
# CPU                                                      #
############################################################

# Aggregate and per-core jiffies. Only user..steal are summed: guest and
# guest_nice are already counted inside user and nice, and adding them again
# inflates the denominator on a machine running VMs. Idle is idle + iowait —
# a core blocked on the disk is not a core doing work.
cpu_counters=$(awk '
	/^cpu/ {
		total = 0
		for (i = 2; i <= 9 && i <= NF; i++)
			total += $i
		idle = $5 + $6
		entry = sprintf("{\"total\":%d,\"idle\":%d}", total, idle)
		if ($1 == "cpu")
			agg = entry
		else
			cores = cores (cores == "" ? "" : ",") entry
	}
	END { printf "{\"total\":%s,\"cores\":[%s]}", agg, cores }
' /proc/stat)

# The mean of what the cores are clocked at, in MHz. cpufreq is the live
# figure; /proc/cpuinfo is the fallback on a kernel or a CPU without it.
cpu_freq=$(awk '{ s += $1; n++ } END { if (n) printf "%.0f", s / n / 1000 }' \
	/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
if [ -z "$cpu_freq" ]; then
	cpu_freq=$(awk -F: '/^cpu MHz/ { s += $2; n++ } END { if (n) printf "%.0f", s / n }' /proc/cpuinfo)
fi

cpu_freq_max=$(awk '{ if ($1 > m) m = $1 } END { if (m) printf "%.0f", m / 1000 }' \
	/sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq 2>/dev/null)

# Package temperature. coretemp's temp1 is "Package id 0" on Intel; k10temp's
# is Tctl on AMD, which is the figure AMD's own boost algorithm reads.
cpu_temp=""
if cpu_hwmon=$(hwmon_for coretemp k10temp zenpower); then
	cpu_temp=$(temp_from "$cpu_hwmon/temp1_input")
fi

read -r load1 load5 load15 _ </proc/loadavg
cpu_model=$(awk -F: '/^model name/ { sub(/^ */, "", $2); print $2; exit }' /proc/cpuinfo)

############################################################
# GPU                                                      #
############################################################

# NVIDIA answers in one call. Anything the card does not report comes back as
# "[N/A]", which the parse below turns into null rather than into 0 — a card
# with no fan tachometer is not a card whose fan is stopped.
gpu_json=null
if command -v nvidia-smi >/dev/null 2>&1; then
	gpu_csv=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,fan.speed,memory.used,memory.total,power.draw,power.limit,clocks.current.sm,clocks.current.memory,pcie.link.gen.current,pcie.link.width.current \
		--format=csv,noheader,nounits 2>/dev/null | head -1)
	if [ -n "$gpu_csv" ]; then
		# Every field is optional: "[N/A]" is what nvidia-smi prints for a
		# figure this card does not report, and it has to become null rather
		# than 0 — a card with no tachometer is not a card whose fan is
		# stopped. `num` is the filter that draws that line.
		gpu_json=$(printf '%s' "$gpu_csv" | jq -Rc '
			def num: (. // "") | if test("^-?[0-9.]+$") then tonumber else null end;
			# nvidia-smi reports memory in MiB; every other size here is bytes.
			def mib: num | if . then . * 1048576 else null end;
			[splits(", *")] as $f
			| {
				vendor: "nvidia",
				name: ($f[0] | sub("^NVIDIA *"; "")),
				util: ($f[1] | num),
				temp: ($f[2] | num),
				fan: ($f[3] | num),
				memUsed: ($f[4] | mib),
				memTotal: ($f[5] | mib),
				power: ($f[6] | num),
				powerLimit: ($f[7] | num),
				clockSm: ($f[8] | num),
				clockMem: ($f[9] | num),
				pcieGen: ($f[10] | num),
				pcieWidth: ($f[11] | num)
			}')
	fi
fi

# AMD, so this panel is not blank on a machine without an NVIDIA card. The
# kernel exposes the same figures through the DRM device and its hwmon, just
# one file at a time.
if [ "$gpu_json" = null ] && [ -r /sys/class/drm/card0/device/gpu_busy_percent ]; then
	amd=/sys/class/drm/card0/device
	read -r amd_util <"$amd/gpu_busy_percent" 2>/dev/null
	read -r amd_used <"$amd/mem_info_vram_used" 2>/dev/null || amd_used=
	read -r amd_total <"$amd/mem_info_vram_total" 2>/dev/null || amd_total=
	amd_temp=""
	amd_fan=""
	amd_power=""
	if amd_hwmon=$(hwmon_for amdgpu); then
		amd_temp=$(temp_from "$amd_hwmon/temp1_input")
		read -r amd_fan <"$amd_hwmon/pwm1" 2>/dev/null || amd_fan=
		# pwm1 is 0..255; the panel speaks percent.
		[ -n "$amd_fan" ] && amd_fan=$(awk -v p="$amd_fan" 'BEGIN { printf "%.0f", p * 100 / 255 }')
		read -r amd_uw <"$amd_hwmon/power1_average" 2>/dev/null || amd_uw=
		[ -n "$amd_uw" ] && amd_power=$(awk -v u="$amd_uw" 'BEGIN { printf "%.2f", u / 1000000 }')
	fi
	gpu_json=$(jq -nc \
		--arg name "$(awk -F= '/^DRIVER=/ { print toupper($2) }' "$amd/uevent" 2>/dev/null)" \
		--arg util "${amd_util:-}" --arg temp "${amd_temp:-}" --arg fan "${amd_fan:-}" \
		--arg used "${amd_used:-}" --arg total "${amd_total:-}" --arg power "${amd_power:-}" \
		'def num: if . == "" then null else tonumber end;
		{
			vendor: "amd",
			name: (if $name == "" then "GPU" else $name end),
			util: ($util | num), temp: ($temp | num), fan: ($fan | num),
			memUsed: ($used | num), memTotal: ($total | num),
			power: ($power | num), powerLimit: null,
			clockSm: null, clockMem: null, pcieGen: null, pcieWidth: null
		}')
fi

############################################################
# MEMORY                                                   #
############################################################

# MemAvailable rather than MemFree: the kernel's own estimate of what a new
# allocation could actually get, which is the only one of the two that means
# anything on a machine with a large page cache. Everything is kB in the file
# and bytes out of it.
mem_json=$(awk '
	/^MemTotal:/     { total = $2 }
	/^MemAvailable:/ { avail = $2 }
	/^MemFree:/      { free = $2 }
	/^Cached:/       { cached = $2 }
	/^SReclaimable:/ { slab = $2 }
	/^Shmem:/        { shmem = $2 }
	/^SwapTotal:/    { swtotal = $2 }
	/^SwapFree:/     { swfree = $2 }
	END {
		printf "{\"total\":%d,\"available\":%d,\"free\":%d,\"cached\":%d,\"swapTotal\":%d,\"swapFree\":%d}",
			total * 1024, avail * 1024, free * 1024,
			(cached + slab - shmem) * 1024, swtotal * 1024, swfree * 1024
	}
' /proc/meminfo)

############################################################
# DISK                                                     #
############################################################

# The root filesystem's disk, whatever it is called on this machine. The
# source can carry a btrfs subvolume in brackets, which is not a device node;
# strip it before asking lsblk for the parent of the partition.
disk_source=$(findmnt -no SOURCE / 2>/dev/null | sed 's/\[.*//')
disk_name=$(lsblk -no PKNAME "$disk_source" 2>/dev/null | head -1)
# A whole-disk root (no partition table) has no parent; it is its own device.
[ -z "$disk_name" ] && disk_name=$(basename "$disk_source")

# statfs, which on this machine's btrfs agrees with `btrfs filesystem usage`
# to within a hundredth of a gigabyte. A multi-device or mixed-profile
# filesystem would need btrfs' own accounting; a single-device one does not.
disk_usage=$(df -B1 --output=size,used / 2>/dev/null | tail -1)
disk_size=$(printf '%s' "$disk_usage" | awk '{ print $1 }')
disk_used=$(printf '%s' "$disk_usage" | awk '{ print $2 }')

# Sectors here are always 512 bytes regardless of the drive's own sector
# size — it is the unit /proc/diskstats is defined in, not a hardware figure.
# ioMs is the time the queue was non-empty, which is what turns into a busy
# percentage once the caller divides it by the interval.
disk_counters=$(awk -v d="$disk_name" '$3 == d { printf "{\"read\":%d,\"written\":%d,\"ioMs\":%d}", $6 * 512, $10 * 512, $13; found = 1 }
	END { if (!found) printf "null" }' /proc/diskstats)

# The NVMe controller's composite temperature. A SATA drive reports nothing
# here — its temperature is behind SMART, which needs root and a command that
# can stall a sleeping disk for seconds.
disk_temp=""
if disk_hwmon=$(hwmon_for nvme); then
	disk_temp=$(temp_from "$disk_hwmon/temp1_input")
fi

############################################################

jq -nc \
	--argjson t "$t" \
	--argjson uptime "${uptime%.*}" \
	--argjson cpu "$cpu_counters" \
	--argjson gpu "$gpu_json" \
	--argjson mem "$mem_json" \
	--argjson diskCounters "${disk_counters:-null}" \
	--arg cpuFreq "${cpu_freq:-}" \
	--arg cpuFreqMax "${cpu_freq_max:-}" \
	--arg cpuTemp "${cpu_temp:-}" \
	--arg cpuModel "${cpu_model:-}" \
	--arg load1 "$load1" --arg load5 "$load5" --arg load15 "$load15" \
	--arg diskName "${disk_name:-}" \
	--arg diskSize "${disk_size:-}" \
	--arg diskUsed "${disk_used:-}" \
	--arg diskTemp "${disk_temp:-}" \
	'def num: if . == "" then null else tonumber end;
	{
		t: $t,
		uptime: $uptime,
		cpu: ($cpu + {
			freq: ($cpuFreq | num),
			freqMax: ($cpuFreqMax | num),
			temp: ($cpuTemp | num),
			model: $cpuModel,
			load: [($load1 | num), ($load5 | num), ($load15 | num)]
		}),
		gpu: $gpu,
		mem: $mem,
		disk: {
			name: $diskName,
			size: ($diskSize | num),
			used: ($diskUsed | num),
			temp: ($diskTemp | num),
			counters: $diskCounters
		}
	}'
