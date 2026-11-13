// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Built-in colour palettes. Each is monochromatic (one hue, five lightness
// steps) and has five colours with fixed roles:
//
//   [0] background   panels, bar, Settings
//   [1] surface      cards and raised areas, the glass gradient
//   [2] muted        borders and dividers
//   [3] text         text and icons
//   [4] accent       highlights, toggles, window borders
//
// Whether a palette is dark or light follows from its background.
// To add one: append an entry with a unique id.

var list = [
    // ---- Dark ---------------------------------------------------------------
    { id: "graphite", name: "Graphite", colors: ["#121316", "#1d1f24", "#3a3d45", "#e6e7ea", "#b4b8c4"] },
    { id: "ocean", name: "Ocean", colors: ["#0b1622", "#132436", "#29486b", "#d6e4f2", "#5aa7e8"] },
    { id: "midnight", name: "Midnight", colors: ["#0c0e1c", "#151a30", "#2b345e", "#d9def5", "#7389f0"] },
    { id: "amethyst", name: "Amethyst", colors: ["#141020", "#211a33", "#3f3363", "#e3dcf5", "#a58bea"] },
    { id: "rose", name: "Rose", colors: ["#1a0f13", "#2a1820", "#523042", "#f2dbe4", "#e87fa6"] },
    { id: "crimson", name: "Crimson", colors: ["#190c0d", "#2a1416", "#55272b", "#f2d9da", "#e5545e"] },
    { id: "amber", name: "Amber", colors: ["#191309", "#2a2010", "#54401f", "#f3e6cf", "#e8a93f"] },
    { id: "mocha", name: "Mocha", colors: ["#17110e", "#261d18", "#4a3a31", "#eadfd7", "#c69a7a"] },
    { id: "forest", name: "Forest", colors: ["#0d1510", "#16241a", "#2d4a35", "#d5e8d9", "#6cc287"] },
    { id: "teal", name: "Teal", colors: ["#0a1717", "#122627", "#24494b", "#d3ebea", "#4fc4bd"] },
    // ---- Light --------------------------------------------------------------
    { id: "paper", name: "Paper", colors: ["#f4f4f5", "#e7e7ea", "#c4c5cb", "#1d1e22", "#4b4f5c"] },
    { id: "sky", name: "Sky", colors: ["#eef5fb", "#dde9f5", "#a9c4e0", "#0f2236", "#2f7fd0"] },
    { id: "lilac", name: "Lilac", colors: ["#f4f1fb", "#e7e0f6", "#c5b6e8", "#1f1733", "#7c5cd6"] },
    { id: "blush", name: "Blush", colors: ["#fbf1f3", "#f3e0e5", "#dcb2be", "#2e141c", "#c94c76"] },
    { id: "sand", name: "Sand", colors: ["#f8f3ea", "#eee4d2", "#d4c3a2", "#2b2215", "#b8862e"] },
    { id: "sage", name: "Sage", colors: ["#f1f5f0", "#e1eadf", "#b4c9b0", "#17261a", "#4f8a5c"] }
];

var roles = ["Background", "Surface", "Muted", "Text", "Accent"];

function find(id) {
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id)
            return list[i];
    return null;
}
