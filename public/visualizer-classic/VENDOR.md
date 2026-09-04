# Vendored: OntoPortal BioMixer Visualizer (classic layout)

Source: https://github.com/ontoportal/biomixer-visualizer
Commit: 16f7c1d249f429931040eea48f36f2bd47c80c57 (2026-09-01)
License: Apache-2.0 (see LICENSE, NOTICE)

Upstream, unpatched. This is the layout the "larger view" modal has always
shown: view tabs, search and side panels laid out flat, exports in the stage
toolbar. It needs the room a near-viewport dialog has, so the Visualization tab
runs the canvas-first build in ../visualizer instead.

To update: re-copy `index.html`, `app.js`, `styles.css`, `LICENSE` and `NOTICE`
from upstream and bump the commit above. Nothing here is patched — keep it that
way so updates stay a straight copy.
