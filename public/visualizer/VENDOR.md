# Vendored: OntoPortal BioMixer Visualizer

Source: https://dev.matportal.org/biomixer-visualizer/ (fetched 2026-09-04)
Upstream: https://github.com/ontoportal/biomixer-visualizer @ 16f7c1d
License: Apache-2.0 (see LICENSE, NOTICE)

Not a straight copy of upstream. MatPortal runs upstream plus its own
canvas-first rework — the menubar, the collapsible side drawers behind the
floating toggles, the diagram annotation layer and atlas paging — appended to
`app.js` and `styles.css` as patch layers (their comments name them "P0",
"P0.3", "UX tighten"). That work is published nowhere but their deployment, so
this is a copy of it, de-branded: only the `<title>` and the brand eyebrow in
`index.html` differ.

Served from `public/`, so the Visualization tab works with no extra
deployment. Point `$VISUALIZER_URL` at a separately hosted copy to override —
which then serves the modal too, in place of ../visualizer-classic.

Only the Visualization tab runs this build. The modal keeps the classic layout
in ../visualizer-classic, which is upstream unpatched.

Embed parameters this build adds: `hide_drawers` suppresses the side drawers,
`open_panels` opens both. Otherwise the drawers start collapsed and remember
their state per browser.

To update: re-copy `index.html`, `app.js`, `styles.css`, `LICENSE` and
`NOTICE`, redo the two de-branding edits, and bump the source above. Nothing
else here is patched — keep it that way.
