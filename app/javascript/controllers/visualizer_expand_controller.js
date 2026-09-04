import { Controller } from '@hotwired/stimulus'

// Wires the Visualization tab's embed to the two things it cannot do from inside
// its own iframe: take the page over, and open itself in the modal.
//
// Taking over — the class tree takes a third of the page, so the tab column is
// narrower than the visualizer's own breakpoints and it collapses its side
// drawers to keep the graph readable. Its fullscreen button posts
// `biomixer_full_screen_request` to its embedder — the contract the legacy
// BioMixer embed used — and the page answers by dropping the class tree, the
// splitter gutter and the tab bar, growing the embed to a full viewport (see
// concepts.scss) and scrolling it flush to the top. The tab's iframe withholds
// the Fullscreen API (see _biomixer.html.haml) so only one of the two fires.
//
// The modal — the vendored copy is same-origin, so the "larger view" button
// belongs at the right of the visualizer's own top bar rather than floating above
// the embed.
// The link itself stays in this document, hidden, because its modal wiring lives
// here; the injected button only forwards clicks to it. A cross-origin
// $VISUALIZER_URL makes the injection throw, and the link stays visible.
//
// Connects to data-controller="visualizer-expand".
const EXPANDED_CLASS = 'is-visualizer-expanded'

const FULLSCREEN_REQUEST = 'biomixer_full_screen_request'

const BUTTON_ID = 'ontoportal-larger-view'

// Below this the visualizer hides the search box, leaving its column empty.
const SEARCH_BREAKPOINT_PX = 1100

const EXPAND_GLYPH = '⤢'

// The frame is already navigating when this controller connects, so poll for its
// top bar. Bounded, with the load event as a backstop for a slow frame.
const INJECT_TIMEOUT_MS = 5000

// The button rides in the search box's row, the last cell of the top bar, so it
// lands at the right edge. That row is hidden once the search is — the id beats
// the vendored rule — and the search itself stays hidden there, leaving the
// column to the button. Styled as a sibling pill to .opv-menubar, so it reads as
// part of the bar in either theme.
const BUTTON_CSS = `
  #app .opv-top-actions {
    display: grid !important;
    grid-template-columns: 1fr auto !important;
    justify-items: end;
  }

  @media (max-width: ${SEARCH_BREAKPOINT_PX}px) {
    #app .opv-top-actions .opv-search { display: none !important; }
  }

  #${BUTTON_ID} {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 32px;
    padding: 0 .6rem;
    border: 1px solid var(--opv-line);
    border-radius: 5px;
    background: var(--opv-surface-strong);
    color: var(--opv-muted);
    font: inherit;
    font-size: .78rem;
    font-weight: 850;
    white-space: nowrap;
    cursor: pointer;
  }

  #${BUTTON_ID}:hover {
    background: var(--opv-surface-muted);
    color: var(--opv-teal-strong);
  }
`

export default class extends Controller {
  static targets = ['trigger']
  static values = { label: String }

  connect () {
    this.frame = this.element.querySelector('iframe')
    this.layout = this.element.closest('#bd_content')
    if (!this.frame || !this.layout) return

    this.onMessage = (event) => this.#onMessage(event)
    window.addEventListener('message', this.onMessage)

    this.onLoad = () => this.#addLargerViewButton()
    this.frame.addEventListener('load', this.onLoad)
    this.#injectWhenReady()
  }

  disconnect () {
    if (this.onMessage) window.removeEventListener('message', this.onMessage)
    if (this.onLoad) this.frame?.removeEventListener('load', this.onLoad)
    this.layout?.classList.remove(EXPANDED_CLASS)
  }

  #onMessage (event) {
    if (event.source !== this.frame.contentWindow) return
    if (event.origin !== this.#frameOrigin()) return
    if (event.data !== FULLSCREEN_REQUEST) return

    if (this.layout.classList.toggle(EXPANDED_CLASS)) {
      // The embed is a viewport tall and everything above it stays in the page,
      // so it only reads as fullscreen once scrolled to the top.
      this.element.scrollIntoView()
    }
  }

  #injectWhenReady () {
    const deadline = performance.now() + INJECT_TIMEOUT_MS
    const tick = () => {
      if (this.#addLargerViewButton() || performance.now() > deadline) return
      requestAnimationFrame(tick)
    }
    tick()
  }

  // True once the button is in place (or already was), so the poll can stop.
  #addLargerViewButton () {
    const link = this.hasTriggerTarget && this.triggerTarget.querySelector('a')
    const doc = this.#frameDocument()
    if (!link || !doc || doc.URL === 'about:blank' || !doc.head) return false
    if (doc.getElementById(BUTTON_ID)) return true

    const topActions = doc.querySelector('.opv-top-actions')
    if (!topActions) return false // markup still parsing

    const style = doc.createElement('style')
    style.textContent = BUTTON_CSS
    doc.head.append(style)

    const label = doc.createElement('span')
    label.textContent = this.labelValue

    const button = doc.createElement('button')
    button.id = BUTTON_ID
    button.type = 'button'
    button.title = this.labelValue
    button.setAttribute('aria-label', this.labelValue)
    button.append(EXPAND_GLYPH, label)
    button.addEventListener('click', () => link.click())
    topActions.append(button)

    this.triggerTarget.hidden = true
    return true
  }

  // The vendored copy is same-origin; $VISUALIZER_URL points elsewhere.
  #frameOrigin () {
    try {
      return new URL(this.frame.getAttribute('src'), window.location.href).origin
    } catch {
      return null
    }
  }

  // Null when the visualizer is hosted on another origin ($VISUALIZER_URL).
  #frameDocument () {
    try {
      return this.frame.contentDocument
    } catch {
      return null
    }
  }
}
