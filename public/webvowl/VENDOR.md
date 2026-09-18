# Vendored: WebVOWL

Source: https://service.tib.eu/webvowl/ (fetched 2026-09-18)
Upstream: https://github.com/VisualDataWeb/WebVOWL @ v1.1.7 (28e7dd9)
License: MIT (see LICENSE). `js/d3.min.js` is D3 v3, BSD-3-Clause, (c) Mike Bostock.

Copied from the TIB deployment rather than built, because upstream publishes no
build artifacts and the toolchain is node 12 / webpack 1 / grunt (their own
`docker/Dockerfile.frontend` pins `node:12-alpine`). To rebuild instead:

    docker compose -f docker-compose.frontend.yml build   # then copy /build/deploy

Note the TIB copy is the *development* build — `webvowl.js` and `webvowl.app.js`
are unminified, which is most of the 1.1 MB. A `grunt release` build would be
smaller; drop it in here when one is available.

Only the class page's VOWL tab serves this, from `public/`, so it works with no
extra deployment. WebVOWL does not load the ontology through its own converter
path: those loaders (`#url=`, `#iri=`) go through the OWL2VOWL Java service,
which we do not run. It is pointed at `/ajax/webvowl_data` instead, through the
one loader that needs no server — the one it uses for the ontologies it ships
(see `vowl_embed_url` in app/helpers/concepts_helper.rb). What it gets back is
the selected class's neighbourhood as VOWL, built by VowlOntologyService.

The six demo ontologies WebVOWL ships under `data/` are deliberately not copied:
the embed hides the Ontology menu that reaches them (webvowl_controller.js), since
every entry in it is a dead end here. `data/new_ontology.json` is kept because it
belongs to the app, not to that menu.

One edit to `index.html`, marked in place — keep the rest a straight copy:

  - `Version: <%= version %>` -> `Version: 1.1.7`. The TIB build shipped the
    grunt template unexpanded.

To update: re-copy the files, redo the edit, and bump the source above.
