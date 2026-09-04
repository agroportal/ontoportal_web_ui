import { Controller } from '@hotwired/stimulus'

// Mounts the vendored Ontology Playground viewer (public/ontology-embed) on the
// .ontology-embed container inside this element.
//
// Two reasons the widget cannot just be a <script> tag in the partial. It is 780 KB
// — React and Cytoscape inlined — so it is loaded only once the Playground tab is
// actually opened, not on every class page. And it auto-mounts on DOMContentLoaded,
// which is long past by the time this lazy turbo-frame arrives, so the mount has to
// be driven by hand through the window.OntologyEmbed.init() it exposes for exactly
// this case.
//
// Connects to data-controller="ontology-playground".
export default class extends Controller {
  static values = { script: String, errorMessage: String }

  connect () {
    this.#load().then(() => this.#mount()).catch(() => this.#showError())
  }

  // Resolves once window.OntologyEmbed is available. The script is shared by every
  // instance on the page and survives turbo frame swaps, so the promise is cached on
  // window rather than on the controller, which a swap would throw away.
  #load () {
    if (window.OntologyEmbed) return Promise.resolve()
    if (window.__ontologyEmbedLoading) return window.__ontologyEmbedLoading

    window.__ontologyEmbedLoading = new Promise((resolve, reject) => {
      const script = document.createElement('script')
      script.src = this.scriptValue
      script.addEventListener('load', resolve)
      script.addEventListener('error', () => {
        // Let a later tab open retry rather than caching the failure for good.
        window.__ontologyEmbedLoading = null
        reject(new Error(`Could not load ${this.scriptValue}`))
      })
      document.head.append(script)
    })
    return window.__ontologyEmbedLoading
  }

  #mount () {
    // The frame may have been swapped away while the script was in flight.
    if (!this.element.isConnected) return

    window.OntologyEmbed?.init()
  }

  #showError () {
    if (!this.element.isConnected) return

    this.element.textContent = this.errorMessageValue
  }
}
