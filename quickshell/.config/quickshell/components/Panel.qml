import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// Shared chrome for the bar's click-open panels: the card, the dismissal
// rules, and the keyboard.
//
// These replaced hover tooltips on the modules whose content is worth reading
// rather than glancing at. A tooltip cannot hold a meter or a two-column table,
// and it is gone the moment you look away from it — so those modules open one
// of these instead, and the tooltip stays only on the modules whose whole
// content really is the one line it can show.
//
// Content goes in as children; they are laid out in a column.
PanelWindow {
	id: root

	property bool open: false
	// Every panel is the same width, so opening two in turn does not read as
	// two unrelated pieces of UI. Overridable, but only one thing overrides it:
	// the launcher, which is not a card raised from a bar module but a window
	// summoned into the middle of the screen, and reads as its own kind of
	// thing on purpose.
	property int cardWidth: 360
	// The width of the surface the card is drawn on, which is the card's own
	// unless a panel says otherwise. The launcher does: its card is 620 wide in
	// most modes and 900 in the clipboard, and a layer-shell surface that
	// changes size while it is on screen is one Hyprland animates by scaling
	// its buffer into the box -- the old, wider card left smeared past the edge
	// of the new one for the length of the animation. Held at the widest it
	// will ever need, the surface never resizes and there is nothing to smear;
	// the card changes width inside it, which is a repaint and not a resize.
	//
	// The cost is the strip of surface either side of a narrow card, which
	// `mask` below hands back to whatever is underneath.
	property int surfaceWidth: cardWidth
	readonly property int pad: 14

	default property alias content: layout.data

	// For content that has to take the keyboard: hand it back here when done.
	function takeFocus(): void {
		card.forceActiveFocus();
	}

	signal dismissed
	signal refreshRequested
	// Anything the panel itself did not claim, for content that has keys of its
	// own (the calendar walks months with the arrows).
	signal keyPressed(var event)

	visible: open
	// Reopening always puts the keyboard back on the card. Content that takes
	// it for itself -- the network panel's password field -- would otherwise
	// leave the panel deaf to its own keys, Escape included, from the moment it
	// was first typed into.
	onVisibleChanged: {
		if (visible)
			takeFocus();
	}
	// One panel, on whichever monitor has focus, rather than one per screen:
	// they are as likely to be summoned by a keybind, which has no screen of
	// its own, as by a click on a particular bar.
	screen: Hyprland.focusedMonitor?.screen ?? null

	// Overlay, so a panel is not buried by a fullscreen window. exclusiveZone 0
	// keeps it from reserving space of its own while still placing it under the
	// bar's zone rather than behind it. Anchoring only the top edge leaves the
	// compositor to centre it; panels for a module off to one side anchor that
	// side as well.
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell:panel"
	// OnDemand rather than Exclusive: the focus grab below hands it the
	// keyboard while it is up, and taking the keyboard outright would mean a
	// panel left open silently swallowing everything typed at the terminal.
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

	anchors.top: true
	margins.top: 8
	exclusiveZone: 0
	color: "transparent"

	implicitWidth: root.surfaceWidth
	implicitHeight: card.implicitHeight

	// Only the card takes clicks. Without this the empty surface beside a
	// narrow card would swallow them: the compositor would hand them to a
	// window that draws nothing there, and the focus grab would read them as
	// clicks *inside* the panel and refuse to dismiss it.
	mask: Region {
		item: card
	}

	// `data` spelled out rather than left to the default property, which the
	// alias above has already spoken for — these are the panel's own frame, not
	// the content going inside it.
	data: [
		// Clicking anywhere outside dismisses, and the keyboard comes here
		// while the panel is up so Escape and R land. Without the grab each
		// panel would be a window you had to remember to close.
		HyprlandFocusGrab {
			windows: [root]
			active: root.visible
			onCleared: root.dismissed()
		},

		Rectangle {
			id: card

			// Centred on the surface, which only means anything when the two
			// are different widths -- see `surfaceWidth`.
			x: (root.width - width) / 2

			implicitWidth: root.cardWidth
			implicitHeight: layout.implicitHeight + root.pad * 2

			// The width change animated here rather than left to the
			// compositor, which is the whole point of holding the surface at
			// `surfaceWidth`. Hyprland animates a resize by scaling the
			// surface's buffer into the box it is interpolating, so the card
			// arrives stretched and a copy of its old self hangs past the edge
			// until the animation ends. Animating the card *inside* a surface
			// that never resizes is a real relayout every frame: the rows
			// reflow, the text re-elides, and there is no second copy to smear.
			//
			// Only the launcher ever changes width, so this is dead weight on
			// every other panel -- and Behaviors do not fire while a component
			// is still being built, so none of them animate up from nothing on
			// first open.
			Behavior on implicitWidth {
				// Only while the panel is up. The launcher's width follows its
				// mode, and its mode follows a query that is set *before* the
				// window is shown -- so opening the apps launcher straight
				// after the clipboard one had the card arrive 900 wide and
				// visibly shed the difference. Off while hidden, the same
				// change lands instantly and the panel opens at the width it
				// meant to open at; on while visible, typing or deleting the
				// `:` that switches mode still animates.
				enabled: root.visible

				NumberAnimation {
					duration: 180
					easing.type: Easing.OutCubic
				}
			}

			radius: 10
			color: Theme.tooltipBg
			border.width: 1
			border.color: Theme.tooltipBorder

			focus: true
			Keys.onEscapePressed: root.dismissed()
			Keys.onPressed: event => {
				if (event.key === Qt.Key_R)
					root.refreshRequested();
				else
					root.keyPressed(event);
			}

			ColumnLayout {
				id: layout

				anchors.fill: parent
				anchors.margins: root.pad
				spacing: 14
			}
		}
	]
}
