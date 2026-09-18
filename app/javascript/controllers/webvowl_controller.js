import { Controller } from '@hotwired/stimulus'

// Trims the chrome of the vendored WebVOWL app (public/webvowl) running in the
// frame inside this element.
//
// Only its Ontology menu goes: every entry is a dead end here. The six ontologies
// it ships with are not vendored, and its IRI and file converters run through the
// OWL2VOWL Java service we do not deploy — and all any of them could do is replace
// the class the tab is about. The rest of the bar (search, export, filters, modes)
// acts on what is on screen, so it stays.
//
// The rule has to be injected because a stylesheet on this page cannot reach into
// a frame — which is the only reason this is a controller and not a few lines in
// concepts.scss.
//
// Connects to data-controller="webvowl".

// `#menuElementContainer > li` styles the bar's items, which outranks a bare id,
// hence the matching shape rather than a flat '#c_select'.
const EMBED_CSS = '#menuElementContainer > li#c_select, #m_select { display: none; }'

export default class extends Controller {
  static targets = ['frame']

  connect () {
    this.frameTarget.addEventListener('load', () => this.#trimChrome())
  }

  #trimChrome () {
    const frameDocument = this.frameTarget.contentDocument
    if (!frameDocument) return

    const style = frameDocument.createElement('style')
    style.textContent = EMBED_CSS
    frameDocument.head.append(style)
  }
}
