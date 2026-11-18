import { Controller } from "@hotwired/stimulus"

// Drives the admin ontologies table actions (process / delete / OOPS / view
// toggle) without jQuery. Server responses are Turbo Streams, applied in place.
export default class extends Controller {
  static targets = ["action", "checkbox"]
  static values = { processUrl: String }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach((cb) => { cb.checked = checked })
  }

  selectedAcronyms() {
    return this.checkboxTargets.filter((cb) => cb.checked).map((cb) => cb.value)
  }

  showAll(event) {
    event.preventDefault()
    this.#rows().forEach((row) => { row.style.display = "" })
  }

  showProblemOnly(event) {
    event.preventDefault()
    this.#rows().forEach((row) => {
      row.style.display = row.classList.contains("problem") ? "" : "none"
    })
  }

  async performAction(event) {
    event.preventDefault()
    const action = this.hasActionTarget ? this.actionTarget.value : ""
    if (!action) {
      window.alert(this.element.dataset.alertChoose || "Please choose an action.")
      return
    }

    const acronyms = this.selectedAcronyms()
    if (acronyms.length === 0) {
      window.alert(this.element.dataset.alertSelect || "Please select at least one ontology.")
      return
    }

    if (!window.confirm(`${action} → ${acronyms.join(", ")}\n\nProceed?`)) return

    const method = action === "delete" ? "DELETE" : "PUT"
    const body = new URLSearchParams()
    body.append("ontologies", acronyms.join(","))
    if (action !== "delete") body.append("actions", action)

    const response = await fetch(this.processUrlValue, {
      method,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": this.#csrfToken(),
      },
      body: body.toString(),
    })

    const data = await response.json().catch(() => ({}))
    this.#showMessage(data)
    this.#reloadFrame()
  }

  #showMessage(data) {
    const box = document.getElementById("admin_ontologies_messages")
    if (!box) return
    const type = (data.errors && data.errors.length) ? "danger" : "success"
    const text = (data.errors && data.errors.length) ? data.errors : (data.success || "")
    box.innerHTML = `<div class="alert alert-${type}" role="alert">${text}</div>`
  }

  #reloadFrame() {
    const frame = document.getElementById("ontology-administration-tab")
    if (frame && typeof frame.reload === "function") frame.reload()
  }

  #rows() {
    return Array.from(this.element.querySelectorAll("table tbody tr"))
  }

  #csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
