#!/bin/bash

# Prints the fingerprint glyph for hyprlock's indicator label, or nothing.
#
# Nothing is the important half. hyprlock's fingerprint auth fails silently --
# it logs that it could not reach fprintd and carries on as a password prompt --
# so an icon that is drawn regardless would be a promise the lock screen cannot
# keep. Three separate things have to be true before it is honest, and
# `fprintd-list` answers all three in one call:
#
#   * fprintd installed -> the command exists at all
#   * a reader present  -> GetDefaultDevice succeeds, so the call does not fail
#   * a finger enrolled -> the user has lines of their own to list
#
# The listing prints one " - #0: right-index-finger" line per enrolled finger
# and a "has no fingers enrolled" sentence when there are none, so the grep is
# for the numbered lines rather than against the sentence: an fprintd that
# rewords its prose cannot turn the icon on by accident.

command -v fprintd-list >/dev/null || exit 0

fprintd-list "$USER" 2>/dev/null | grep -q '#[0-9]' || exit 0

# U+F0237, nf-md-fingerprint. The rest of the lock screen is set in
# JetBrainsMono Nerd Font, so the glyph is already in the face being used.
echo "󰈷"
