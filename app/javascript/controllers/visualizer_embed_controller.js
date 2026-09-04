import { Controller } from '@hotwired/stimulus'

// Re-skins the embedded visualizer for the narrow Visualization tab: one compact
// menu bar, the rest of the pane given to the graph, and the two side panels
// tucked behind edge handles.
//
// The class tree takes a third of the page, so the tab is narrower than the
// visualizer's own 1180px breakpoint. Below it the visualizer stacks its header,
// side panels and stage toolbar into a single column and forces a 760px
// min-height, which is what buried the graph under four rows of chrome.
//
// Nothing is rebuilt: the original controls are MOVED into the new bar and
// drawers, so every listener the app attached to them still fires and the app's
// own cached element references stay valid. Everything stays inside #app.
//
// The visualizer is vendored under public/visualizer, so the iframe is same-origin
// and we can restyle its document from out here — which keeps the vendored copy an
// unpatched mirror of upstream. If $VISUALIZER_URL points at another origin the
// access throws and the embed keeps its full-size layout; the modal (see
// _show.html.haml) opens that layout deliberately.
//
// Connects to data-controller="visualizer-embed".
const SKIN_ID = 'ontoportal-compact-embed'

// The iframe is already navigating when this controller connects, so poll for its
// document and skin it as soon as <head> exists — that lands before the deferred
// app.js first paints, so the full-size chrome never flashes. Bounded, with the
// load event as a backstop for a slow or re-navigated frame.
const INJECT_TIMEOUT_MS = 5000

const MENUS = [
  { label: 'Visualization', source: '.opv-view-tabs' },
  { label: 'Download', source: '.opv-export-menu' },
  { label: 'Actions', source: '.opv-top-actions' }
]

const SKIN_CSS = `
  /* Chrome replaced by the compact bar; the stage toolbar is left empty. */
  .opv-topbar,
  .opv-stage-toolbar { display: none !important; }

  /* The <1180px rules give the shell a 760px floor and let it scroll. */
  html, body, #app { min-height: 0 !important; }

  /* Row 1 was the hidden topbar; with it gone .opv-main fell into the auto row
     and left the 1fr one empty as a dead band under the graph. */
  .opv-shell {
    grid-template-rows: 1fr !important;
    padding: 0 !important;
    overflow: hidden !important;
  }

  /* Bar, then graph. Visible overflow so a menu can hang over the stage. */
  .opv-main {
    grid-template-columns: 1fr !important;
    grid-template-rows: auto 1fr !important;
    gap: 0 !important;
    padding-top: 0 !important;
    overflow: visible !important;
  }

  /* Row 1 held the toolbar that is now hidden. */
  .opv-stage {
    grid-template-rows: 1fr !important;
    border: 0 !important;
    border-radius: 0 !important;
  }

  /* Fixed slate, not --opv-ink: that variable IS the text colour, so it flips to
     near-white in the dark theme and the bar went white-on-white. The bar reads as
     a toolbar against either theme's canvas. */
  .opc-bar {
    position: relative;
    z-index: 20;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 7px 10px;
    background: #102129;
    color: #f4f8f8;
    font-size: .82rem;
  }

  .opc-menu { position: relative; }

  .opc-menu__button {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border: 0;
    border-radius: 8px;
    background: transparent;
    color: inherit;
    font: inherit;
    font-weight: 700;
    cursor: pointer;
  }
  .opc-menu__button:hover,
  .opc-menu[data-open="true"] .opc-menu__button { background: rgba(255, 255, 255, .14); }
  .opc-menu__button::after { content: "▾"; font-size: .7em; opacity: .7; }

  .opc-menu__panel {
    position: absolute;
    top: calc(100% + 6px);
    left: 0;
    z-index: 30;
    padding: 10px;
    min-width: 220px;
    border: 1px solid var(--opv-line);
    border-radius: 12px;
    background: var(--opv-surface-strong);
    box-shadow: var(--opv-shadow-md);
  }
  .opc-menu__panel[hidden] { display: none; }

  /* The moved controls were laid out for a wide header; stack them here. */
  .opc-menu__panel .opv-view-tabs { grid-template-columns: 1fr; border: 0; background: none; padding: 0; }
  .opc-menu__panel .opv-export-menu { flex-direction: column; }
  .opc-menu__panel .opv-top-actions { grid-template-columns: 1fr; gap: 10px; }

  /* Status and metrics read against the dark bar. */
  .opc-bar .opv-status { min-width: 0; border-color: rgba(255, 255, 255, .2); background: rgba(255, 255, 255, .1); color: #fff; }
  .opc-bar .opv-metrics { color: rgba(255, 255, 255, .82); }

  /* Side panels become drawers clipped to the stage, behind an edge handle. */
  .opc-drawer {
    position: absolute;
    top: 0;
    bottom: 0;
    z-index: 15;
    width: min(320px, 78%);
    padding: 12px !important;
    overflow: auto;
    /* Beats .is-embed's translucent panel fill, which let the graph show through. */
    background: var(--opv-surface-strong) !important;
    border: 0 !important;
    box-shadow: var(--opv-shadow-md);
    transition: transform .18s ease;
  }

  /* The left panel goes two cards across below 1180px; one column in a drawer. */
  .opc-drawer.opv-left-panel {
    display: grid !important;
    grid-template-columns: 1fr !important;
    gap: 12px;
    align-content: start;
  }
  .opc-drawer--left { left: 0; transform: translateX(-101%); }
  .opc-drawer--right { right: 0; transform: translateX(101%); }
  .opc-drawer.is-open { transform: translateX(0); }

  .opc-handle {
    position: absolute;
    top: 50%;
    z-index: 16;
    transform: translateY(-50%);
    padding: 18px 5px;
    border: 0;
    border-radius: 6px;
    background: #102129;
    color: #f4f8f8;
    font-size: .7rem;
    line-height: 1;
    cursor: pointer;
  }
  .opc-handle--left { left: 0; }
  .opc-handle--right { right: 0; }

  /* A drawer must not sit under its own handle. */
  .opc-drawer--left.is-open ~ .opc-handle--left { left: min(320px, 78%); }
  .opc-drawer--right.is-open ~ .opc-handle--right { right: min(320px, 78%); }
`

export default class extends Controller {
  connect () {
    this.frame = this.element.querySelector('iframe')
    if (!this.frame) return

    this.onLoad = () => this.#skin()
    this.frame.addEventListener('load', this.onLoad)
    this.#skinWhenReady()
  }

  disconnect () {
    if (this.onLoad) this.frame?.removeEventListener('load', this.onLoad)
  }

  #skinWhenReady () {
    const deadline = performance.now() + INJECT_TIMEOUT_MS
    const tick = () => {
      if (this.#skin() || performance.now() > deadline) return
      requestAnimationFrame(tick)
    }
    tick()
  }

  // True once the skin is in place (or already was), so the poll can stop.
  #skin () {
    const doc = this.#frameDocument()
    if (!doc || doc.URL === 'about:blank' || !doc.head) return false
    if (doc.getElementById(SKIN_ID)) return true

    const main = doc.querySelector('.opv-main')
    const stage = doc.querySelector('.opv-stage')
    if (!main || !stage) return false // markup still parsing

    const style = doc.createElement('style')
    style.id = SKIN_ID
    style.textContent = SKIN_CSS
    doc.head.append(style)

    main.prepend(this.#buildBar(doc))
    this.#buildDrawer(doc, stage, '.opv-left-panel', 'left', 'Graph tools')
    this.#buildDrawer(doc, stage, '.opv-detail-panel', 'right', 'Selected class')

    doc.addEventListener('click', () => this.#closeMenus(doc))
    doc.addEventListener('keydown', (ev) => { if (ev.key === 'Escape') this.#closeMenus(doc) })
    return true
  }

  #buildBar (doc) {
    const bar = doc.createElement('div')
    bar.className = 'opc-bar'

    MENUS.forEach(({ label, source }) => {
      const moved = doc.querySelector(source)
      if (moved) bar.append(this.#buildMenu(doc, label, moved))
    })

    // Live status and counts stay visible rather than hiding behind a menu.
    const statusPill = doc.getElementById('statusPill')
    const metrics = doc.querySelector('.opv-metrics')
    if (statusPill) bar.append(statusPill)
    if (metrics) bar.append(metrics)

    return bar
  }

  #buildMenu (doc, label, moved) {
    const menu = doc.createElement('div')
    menu.className = 'opc-menu'

    const button = doc.createElement('button')
    button.type = 'button'
    button.className = 'opc-menu__button'
    button.textContent = label

    const panel = doc.createElement('div')
    panel.className = 'opc-menu__panel'
    panel.hidden = true
    panel.append(moved)

    button.addEventListener('click', (ev) => {
      ev.stopPropagation()
      const open = panel.hidden
      this.#closeMenus(doc)
      panel.hidden = !open
      menu.dataset.open = String(open)
    })

    // Keep the panel open while typing in the search box, close it once a
    // control has been used.
    panel.addEventListener('click', (ev) => {
      ev.stopPropagation()
      if (ev.target.closest('button')) this.#closeMenus(doc)
    })

    menu.append(button, panel)
    return menu
  }

  #buildDrawer (doc, stage, selector, side, label) {
    const panel = doc.querySelector(selector)
    if (!panel) return

    panel.classList.add('opc-drawer', `opc-drawer--${side}`)
    stage.append(panel)

    const handle = doc.createElement('button')
    handle.type = 'button'
    handle.className = `opc-handle opc-handle--${side}`
    handle.title = label
    handle.setAttribute('aria-label', label)

    const closed = side === 'left' ? '▶' : '◀'
    const open = side === 'left' ? '◀' : '▶'
    handle.textContent = closed
    handle.addEventListener('click', (ev) => {
      ev.stopPropagation()
      const isOpen = panel.classList.toggle('is-open')
      handle.textContent = isOpen ? open : closed
    })

    stage.append(handle)
  }

  #closeMenus (doc) {
    doc.querySelectorAll('.opc-menu').forEach((menu) => {
      menu.querySelector('.opc-menu__panel').hidden = true
      menu.dataset.open = 'false'
    })
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
