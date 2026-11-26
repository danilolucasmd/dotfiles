// ==UserScript==
// @name         YouTube grid
// @description  Five videos per row, a compact Shorts shelf and no channel avatars on YouTube.
// @match        https://www.youtube.com/*
// @run-at       document-start
// @qute-js-world main
// ==/UserScript==

// A port of the "YouTube Row Fixer" Brave extension at the settings used there
// (its defaults plus hidden channel avatars). CSS alone cannot do it: YouTube's
// grid controller computes the per-row counts from the window width and sizes
// each shelf ("Latest", the Shorts row) from them, so forcing only the columns
// left shelves with a stray half row. Like the extension, this patches the
// controller so its own layout pass runs with fixed counts, and turns off the
// shelf's newer layout pass, which would otherwise recompute them again.
const VIDEOS_PER_ROW = 5;
const POSTS_PER_ROW = 3;
const SHELF_ITEMS_PER_ROW = 12;
const CHANNEL_VIDEOS_PER_ROW = 5;
const CHANNEL_SHELF_ITEMS_PER_ROW = 8;

// Grid elements keep their logic on a controller object, not on the element.
const controllerPrototype = async (tag) => {
	await customElements.whenDefined(tag);
	const el = document.createElement(tag);
	return (el.polymerController || el.inst || el).constructor.prototype;
};

controllerPrototype("ytd-rich-grid-renderer").then((proto) => {
	const counts = {};
	const refreshGridLayout = proto.refreshGridLayout;
	const calcElementsPerRow = proto.calcElementsPerRow;

	// 310 and 194 are the minimum item widths YouTube passes for a video and a
	// slim item (a short); every other caller keeps the width-based answer.
	proto.calcElementsPerRow = function (minWidth, max) {
		if (minWidth === 310) return counts.elementsPerRow;
		if (minWidth === 194) return counts.slimItemsPerRow;
		return calcElementsPerRow.call(this, minWidth, max);
	};
	proto.calcMaxSlimElementsPerRow = () => counts.slimItemsPerRow;

	const fixed = ["elementsPerRow", "postsPerRow", "slimItemsPerRow", "gameCardsPerRow"];
	proto.refreshGridLayout = function (...args) {
		const channel = this.isChannelPage;
		counts.elementsPerRow = channel ? CHANNEL_VIDEOS_PER_ROW : VIDEOS_PER_ROW;
		counts.postsPerRow = POSTS_PER_ROW;
		counts.slimItemsPerRow = channel ? CHANNEL_SHELF_ITEMS_PER_ROW : SHELF_ITEMS_PER_ROW;
		counts.gameCardsPerRow = counts.slimItemsPerRow;
		// Pinned for the duration of the layout pass, so nothing inside it can
		// write a width-based count back.
		for (const key of fixed) {
			Object.defineProperty(this, key, {
				get: () => counts[key],
				set: () => true,
				configurable: true,
				enumerable: true,
			});
		}
		const result = refreshGridLayout.apply(this, args);
		for (const key of fixed) {
			delete this[key];
			this[key] = counts[key];
		}
		return result;
	};
});

controllerPrototype("ytd-rich-shelf-renderer").then((proto) => {
	proto.refreshGridLayoutNew = () => {};
});

const style = document.createElement("style");
style.textContent = `
	/* Channel avatars beside each video's title. */
	.channel-avatar.ytd-ghost-grid-renderer,
	#home-page-skeleton .channel-avatar,
	.ytLockupMetadataViewModelStandard .ytLockupMetadataViewModelAvatar,
	.yt-lockup-metadata-view-model--standard .yt-lockup-metadata-view-model__avatar,
	.yt-lockup-metadata-view-model-wiz--standard .yt-lockup-metadata-view-model-wiz__avatar,
	#avatar-container.ytd-rich-grid-media,
	ytd-rich-grid-media a#avatar-link {
		display: none !important;
	}

	/* The loading skeleton, so the page does not jump from 3 columns to 5. */
	#home-page-skeleton .rich-grid-media-skeleton,
	#home-page-skeleton .rich-shelf-videos .rich-grid-media-skeleton.mini-mode,
	#home-page-skeleton #home-container-media .rich-grid-media-skeleton.mini-mode {
		min-width: calc(100% / ${VIDEOS_PER_ROW} - 1.6rem) !important;
		max-width: calc(100% / ${VIDEOS_PER_ROW} - 1.6rem) !important;
	}

	[page-subtype="subscriptions"] ytd-rich-shelf-renderer[is-shorts] ytd-rich-item-renderer[is-slim-media],
	[page-subtype="home"] ytd-rich-shelf-renderer[is-shorts] ytd-rich-item-renderer[is-slim-media] {
		width: calc(100% / ${SHELF_ITEMS_PER_ROW} - var(--ytd-rich-grid-item-margin) - 0.01px) !important;
	}
	[page-subtype="subscriptions"] ytd-rich-shelf-renderer[is-shorts] ytd-rich-item-renderer[is-slim-media],
	[page-subtype="home"] ytd-rich-shelf-renderer[is-shorts] ytd-rich-item-renderer[is-slim-media]:nth-child(-n + ${SHELF_ITEMS_PER_ROW}) {
		display: block !important;
	}

	ytd-rich-item-renderer[is-post] {
		width: calc(100% / var(--ytd-rich-grid-posts-per-row) - var(--ytd-rich-grid-item-margin) - 0.01px) !important;
	}
`;
// At document-start qutebrowser runs this before the <html> element exists.
const addStyle = () =>
	document.documentElement ? document.documentElement.append(style) : setTimeout(addStyle, 0);
addStyle();
