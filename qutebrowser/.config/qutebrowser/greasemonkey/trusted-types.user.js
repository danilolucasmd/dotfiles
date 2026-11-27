// ==UserScript==
// @name         Trusted Types passthrough for qutebrowser
// @description  Lets caret mode start on pages that enforce Trusted Types.
// @match        *://*/*
// @run-at       document-start
// @qute-js-world application
// ==/UserScript==

// qutebrowser's caret.js injects its caret stylesheet with `innerHTML`, and on
// any page whose CSP sets `require-trusted-types-for 'script'` (Google Docs,
// YouTube, Gmail...) Chromium rejects that assignment with "This document
// requires 'TrustedHTML' assignment", so caret mode never starts. Enforcement
// reaches the application world qutebrowser runs its own JS in, but a policy
// does not cross worlds: this "default" policy, created in that same world,
// only ever sees qutebrowser's own assignments and leaves the page's
// Trusted Types setup untouched. Drop it once caret.js stops using innerHTML.
if (window.trustedTypes && !trustedTypes.defaultPolicy) {
	trustedTypes.createPolicy("default", { createHTML: (html) => html });
}
