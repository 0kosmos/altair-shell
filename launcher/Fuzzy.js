// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Fuzzy matching for the launcher.
//
// score(query, text) returns -1 for "no match", otherwise higher is better.
// Tiers, so that an obvious match always beats a scattered one:
//   prefix ("fire" → Firefox)              900–1000
//   substring at a word start ("mon" → System Monitor)  700–800
//   other substring                         500–600
//   subsequence ("syset" → System Settings)  1–499, bonuses for letters that
//                                            are consecutive or start a word

function isBoundary(text, i) {
    if (i === 0)
        return true;
    const prev = text[i - 1];
    return prev === " " || prev === "-" || prev === "_" || prev === "." || prev === "/";
}

function score(query, text) {
    if (!text)
        return -1;
    const q = query.toLowerCase();
    const t = text.toLowerCase();
    if (q.length === 0)
        return 0;

    const idx = t.indexOf(q);
    if (idx === 0)
        return 1000 - Math.min(t.length, 100);          // shorter names first
    if (idx > 0)
        return (isBoundary(t, idx) ? 800 : 600) - Math.min(idx + t.length * 0.1, 100);

    let total = 0;
    let ti = 0;
    let prev = -2;
    for (let qi = 0; qi < q.length; qi++) {
        const c = q[qi];
        while (ti < t.length && t[ti] !== c)
            ti++;
        if (ti >= t.length)
            return -1;
        let s = 10;
        if (ti === prev + 1)
            s += 15;
        if (isBoundary(t, ti))
            s += 20;
        s -= Math.min(ti - prev - 1, 10);                // gap penalty
        total += s;
        prev = ti;
        ti++;
    }
    return Math.max(1, Math.min(499, total));
}

// Best score of a desktop entry across its fields, weighted by field.
function scoreEntry(query, entry) {
    let best = score(query, entry.name);
    const others = [
        [entry.genericName, 0.8],
        [entry.id, 0.6],
    ];
    for (const kw of entry.keywords)
        others.push([kw, 0.7]);
    for (const [text, weight] of others) {
        const s = score(query, text);
        if (s > 0)
            best = Math.max(best, s * weight);
    }
    return best;
}

// Filter and rank `entries`. `launches` maps desktop id → launch count; often
// used apps get a boost (log-scaled, so it nudges rather than dominates).
function rank(query, entries, launches) {
    const q = query.trim();
    const boost = e => Math.log2(1 + (launches[e.id] ?? 0)) * 40;

    if (q.length === 0)
        return entries.slice().sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name));

    const scored = [];
    for (const e of entries) {
        const s = scoreEntry(q, e);
        if (s > 0)
            scored.push({ entry: e, score: s + boost(e) });
    }
    scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
    return scored.map(x => x.entry);
}
