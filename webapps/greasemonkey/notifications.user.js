// ==UserScript==
// @name         webapp notification permission
// @match        *://*/*
// @run-at       document-start
// @noframes
// ==/UserScript==

// qutebrowser grants notifications without asking (content.notifications.enabled
// is on for the apps), but it switches off QtWebEngine's permission persistence,
// so every launch starts back at "default". Apps read that as "never asked" and
// put up their enable-notifications banner (WhatsApp does it on every open).
// Asking is answered at once with "granted", no prompt, so ask on every load
// before the app gets to check.
if (window.Notification && Notification.permission === "default") {
	Notification.requestPermission();
}
