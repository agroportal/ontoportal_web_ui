# Vendored: Ontology Playground embed widget

Source: https://github.com/microsoft/Ontology-Playground
Commit: 1f8113ba6f84270a8093584e40c556143a078c39
License: MIT (see LICENSE)

Only the embeddable viewer is vendored, not the playground app: the upstream
repo publishes no build artifacts, so this file is produced from a checkout with

    npm ci && npm run build:embed     # -> build/embed/ontology-embed.js

It is a self-contained IIFE (React + Cytoscape inlined, styles inline, no CSS
file), which is why it is 780 KB — the ontology-playground Stimulus controller loads
it only when the Playground tab is actually opened.

To update: rebuild from a newer checkout, replace the file, and bump the commit
above. Nothing here is patched — keep it that way so updates stay a straight copy.
