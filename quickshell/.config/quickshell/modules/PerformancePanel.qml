import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The performance panel, opened by clicking the bar module or by super+shift+P.
//
// Four subsystems, one meter each, in the order they get blamed: processor,
// graphics, memory, disk. The meter is the same language the usage and battery
// panels speak -- a filled track with the number over it -- because the
// question here is the same one those ask, which is how much of a fixed thing
// is gone.
//
// Under each meter is the line the meter cannot say: what it is clocked at,
// how hot it is, what it is moving. Those are the readings you go looking for
// once the bar glyph has changed colour, and the reason this is a panel rather
// than a tooltip.
//
// It is not btop and does not try to be -- there is no process list here. What
// is running is a question with a whole terminal application already dedicated
// to it; what the machine is doing is a question worth answering in a glance.
Panel {
	id: root

	open: PerformanceState.panelOpen
	onDismissed: PerformanceState.close()
	onRefreshRequested: PerformanceState.refresh()

	// The module sits in the bar's right cluster, so the panel drops from the
	// same corner rather than from the middle of the screen.
	anchors.right: true
	margins.right: 8

	// Green below the first threshold, amber between, red above. The meters
	// ramp on the figure they are drawing rather than on the subsystem's
	// pressure: a meter is answering "how much is left", and a processor at
	// 96% has very little left even though nothing is wrong with it.
	function ramp(value: real, warm: real, hot: real): color {
		const l = PerformanceState.level(value, warm, hot);
		return l >= 2 ? Theme.red : l >= 1 ? Theme.yellow : Theme.green;
	}

	// Temperatures colour on their own thresholds wherever they are printed,
	// so a cool chip's temperature reads as ordinary text and a hot one does
	// not have to be hunted for.
	function tempColor(celsius: real, warm: real, hot: real): color {
		const l = PerformanceState.level(celsius, warm, hot);
		return l >= 2 ? Theme.red : l >= 1 ? Theme.yellow : Theme.dim;
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: "Performance"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: {
				const up = PerformanceState.formatUptime(PerformanceState.stats.uptime ?? 0);
				return up ? `up ${up}` : "";
			}
			color: Theme.dim
		}
	}

	BarText {
		Layout.fillWidth: true
		visible: !PerformanceState.available

		text: "No reading yet."
		color: Theme.dim
		wrapMode: Text.Wrap
	}

	// ------------------------------------------------------------------
	// CPU
	// ------------------------------------------------------------------

	Section {
		visible: PerformanceState.available

		icon: "󰻠"
		label: "CPU"
		// The chip, the way the GPU section names its card. The clock goes on
		// the line below with the load average: it is a live figure and this
		// slot is the one that elides.
		detail: PerformanceState.cpuName
		value: PerformanceState.cpuUsage
		// 100% is a compile, not a fault, so the first band is wide and the
		// red one only opens where the machine has genuinely run out of
		// processor to give.
		accent: root.ramp(PerformanceState.cpuUsage, 80, 95)

		// One bar per core. The aggregate hides the case this is here for: a
		// single-threaded job pinning one core of six reads as 17% on the
		// meter above and as one full column here.
		RowLayout {
			Layout.fillWidth: true
			Layout.topMargin: 2
			spacing: 3

			Repeater {
				model: PerformanceState.coreUsage

				delegate: Rectangle {
					required property real modelData

					Layout.fillWidth: true
					implicitHeight: 14

					radius: 2
					color: Theme.track

					Rectangle {
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: parent.bottom

						height: Math.max(2, Math.min(1, parent.modelData / 100) * parent.height)
						radius: parent.radius
						color: root.ramp(parent.modelData, 80, 95)

						Behavior on height {
							NumberAnimation {
								duration: 250
								easing.type: Easing.OutCubic
							}
						}
					}
				}
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				Layout.fillWidth: true

				// No core count: the strip above is a bar per core, so it is
				// already there to be counted.
				text: {
					const s = PerformanceState;
					const load = s.cpu.load ?? [];
					const parts = [];
					const f = s.formatFreq(s.cpu.freq ?? 0);
					if (f)
						parts.push(f);
					if (load.length === 3)
						parts.push(`load ${load[0].toFixed(2)} ${load[1].toFixed(2)} ${load[2].toFixed(2)}`);
					return parts.join(" · ");
				}
				color: Theme.dim
				elide: Text.ElideRight
			}

			BarText {
				visible: text !== ""
				text: PerformanceState.formatTemp(PerformanceState.cpu.temp ?? 0)
				color: root.tempColor(PerformanceState.cpu.temp ?? 0, PerformanceState.cpuTempWarm, PerformanceState.cpuTempHot)
			}
		}
	}

	// ------------------------------------------------------------------
	// GPU
	// ------------------------------------------------------------------

	Section {
		visible: PerformanceState.gpuPresent

		icon: "󰢮"
		label: "GPU"
		detail: PerformanceState.gpu?.name ?? ""
		value: PerformanceState.gpu?.util ?? 0
		accent: root.ramp(PerformanceState.gpu?.util ?? 0, 80, 95)

		// Video memory is the one that actually runs out, and it runs out
		// abruptly -- a scene that no longer fits does not slow down, it
		// starts swapping over the PCIe bus. So it gets a meter of its own
		// rather than a figure in the detail line.
		Meter {
			Layout.topMargin: 2

			value: PerformanceState.gpuMemPercent
			accent: root.ramp(PerformanceState.gpuMemPercent, 85, 95)
			// Thinner than the section's own meter: this is the subsidiary
			// reading, and two identical bars would read as two equals.
			implicitHeight: 4
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				Layout.fillWidth: true

				text: {
					const g = PerformanceState.gpu;
					if (!g)
						return "";
					return `vram ${PerformanceState.formatBytes(g.memUsed ?? 0, 1)} / ${PerformanceState.formatBytes(g.memTotal ?? 0, 1)}`;
				}
				color: Theme.dim
				elide: Text.ElideRight
			}

			// Only what the card reports. A fan reading of null is a card with
			// no tachometer, which is a different thing from a stopped fan --
			// and a stopped fan is worth showing, because on this card zero
			// below 60°C is the fan-stop curve working rather than a fault.
			BarText {
				visible: PerformanceState.gpu?.fan !== null && PerformanceState.gpu?.fan !== undefined
				text: `󰈐 ${Math.round(PerformanceState.gpu?.fan ?? 0)}%`
				color: Theme.dim
			}

			BarText {
				visible: text !== ""
				text: PerformanceState.formatTemp(PerformanceState.gpu?.temp ?? 0)
				color: root.tempColor(PerformanceState.gpu?.temp ?? 0, PerformanceState.gpuTempWarm, PerformanceState.gpuTempHot)
			}
		}

		BarText {
			Layout.fillWidth: true

			text: {
				const g = PerformanceState.gpu;
				if (!g)
					return "";
				const parts = [];
				if (g.power !== null && g.power !== undefined)
					parts.push(g.powerLimit ? `${Math.round(g.power)} W / ${Math.round(g.powerLimit)} W` : `${Math.round(g.power)} W`);
				if (g.clockSm)
					parts.push(`core ${PerformanceState.formatFreq(g.clockSm)}`);
				// The link the card negotiated *now*, which idles down to gen 1
				// on a desktop and only says something is wrong if it stays
				// there under load.
				if (g.pcieGen && g.pcieWidth)
					parts.push(`PCIe ${g.pcieGen}.0 ×${g.pcieWidth}`);
				return parts.join(" · ");
			}
			color: Theme.dim
			elide: Text.ElideRight
		}
	}

	// ------------------------------------------------------------------
	// Memory
	// ------------------------------------------------------------------

	Section {
		visible: PerformanceState.available

		// md-memory. It is another chip rather than a RAM stick, so it is the
		// weakest of the four here -- at 16px it is not far off the CPU glyph
		// three rows up. Font Awesome has an actual DIMM that reads better,
		// but every other glyph in this shell is Material Design, and one
		// foreign icon in a column of them is more obvious than a chip that
		// could have been a slightly different chip. The label beside it says
		// RAM, which is the part doing the real work.
		icon: "󰍛"
		label: "RAM"
		detail: `${PerformanceState.formatBytes(PerformanceState.memUsed, 1)} / ${PerformanceState.formatBytes(PerformanceState.mem.total ?? 0, 1)}`
		value: PerformanceState.memPercent
		accent: root.ramp(PerformanceState.memPercent, PerformanceState.memWarm, PerformanceState.memHot)

		BarText {
			Layout.fillWidth: true

			text: {
				const s = PerformanceState;
				const parts = [`cache ${s.formatBytes(s.mem.cached ?? 0, 1)}`];
				if (s.mem.swapTotal > 0)
					parts.push(`swap ${s.formatBytes(s.swapUsed, 1)} / ${s.formatBytes(s.mem.swapTotal, 1)}`);
				return parts.join(" · ");
			}
			// Swap that has started filling is the moment memory pressure
			// stops being theoretical, and it is the one thing on this line
			// worth raising a voice about.
			color: PerformanceState.swapUsed > 0 ? Theme.yellow : Theme.dim
			elide: Text.ElideRight
		}
	}

	// ------------------------------------------------------------------
	// Disk
	// ------------------------------------------------------------------

	Section {
		visible: PerformanceState.available

		icon: "󰋊"
		label: "Disk"
		detail: PerformanceState.disk.name ?? ""
		value: PerformanceState.diskPercent
		accent: root.ramp(PerformanceState.diskPercent, PerformanceState.diskWarm, PerformanceState.diskHot)

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				Layout.fillWidth: true

				text: {
					const s = PerformanceState;
					const free = (s.disk.size ?? 0) - (s.disk.used ?? 0);
					return `${s.formatBytes(free, 0)} free of ${s.formatBytes(s.disk.size ?? 0, 0)}`;
				}
				color: Theme.dim
				elide: Text.ElideRight
			}

			BarText {
				visible: text !== ""
				// The NVMe controller's composite sensor. A SATA drive reports
				// nothing here: its temperature is behind SMART, which needs
				// root and can stall a sleeping disk for seconds.
				text: PerformanceState.formatTemp(PerformanceState.disk.temp ?? 0)
				color: root.tempColor(PerformanceState.disk.temp ?? 0, 60, 70)
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 12

			BarText {
				text: `󰇚 ${PerformanceState.formatRate(PerformanceState.diskRead)}`
				color: Theme.dim
			}

			BarText {
				text: `󰕒 ${PerformanceState.formatRate(PerformanceState.diskWrite)}`
				color: Theme.dim
			}

			Item {
				Layout.fillWidth: true
			}

			// Not throughput. This is the share of the interval the queue was
			// not empty, which is what pins at 100% while a drive grinds
			// through small random reads at a few megabytes a second.
			BarText {
				text: `busy ${Math.round(PerformanceState.diskBusy)}%`
				color: PerformanceState.diskBusy >= 90 ? Theme.yellow : Theme.dim
			}
		}
	}

	BarText {
		Layout.fillWidth: true
		text: "r refresh · esc close"
		horizontalAlignment: Text.AlignRight
	}

	// ------------------------------------------------------------------

	// The filled track every meter on this panel draws, including the small
	// one inside the GPU section.
	component Meter: Rectangle {
		id: meter

		property real value: 0
		property color accent: Theme.green

		Layout.fillWidth: true
		implicitHeight: 6

		radius: height / 2
		color: Theme.track

		Rectangle {
			width: Math.min(1, meter.value / 100) * meter.width
			height: meter.height
			radius: meter.radius
			color: meter.accent

			Behavior on width {
				NumberAnimation {
					duration: 250
					easing.type: Easing.OutCubic
				}
			}
		}
	}

	// One subsystem: a header naming it, the percentage, the meter, and
	// whatever detail that subsystem has -- which differs enough between the
	// four that it goes in as children rather than as more properties.
	component Section: ColumnLayout {
		id: section

		property string icon
		property string label
		property string detail
		property real value: 0
		property color accent: Theme.green

		default property alias extra: extras.data

		Layout.fillWidth: true
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			BarText {
				text: section.icon
				color: Theme.fg
				font.pixelSize: Theme.fontIcon
			}

			BarText {
				text: section.label
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}

			// Takes the slack so a long detail -- a graphics card's full model
			// name -- elides here rather than shoving the percentage off the
			// card.
			BarText {
				Layout.fillWidth: true

				text: section.detail
				color: Theme.dim
				elide: Text.ElideRight
			}

			BarText {
				text: `${Math.round(section.value)}%`
				color: section.accent
				font.pixelSize: 15
				font.weight: Font.DemiBold
			}
		}

		Meter {
			value: section.value
			accent: section.accent
		}

		ColumnLayout {
			id: extras

			Layout.fillWidth: true
			spacing: 4
		}
	}
}
