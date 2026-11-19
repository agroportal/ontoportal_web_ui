import { Controller } from "@hotwired/stimulus"

const POLL_INTERVAL_MS = 3000
const POLL_MAX_ATTEMPTS = 100

// Drives the admin ontologies table actions (process / delete / FOOPS / view
// toggle / report refresh) without jQuery.
export default class extends Controller {
  static targets = ["action", "checkbox", "reportDate", "refreshButton"]
  static values = {
    processUrl: String,
    refreshUrl: String,
    reportUrl: String,
    choose: String,
    select: String,
    procLead: String,
    procQueue: String,
    proceed: String,
    deleteLead: String,
    cannotUndo: String,
    refreshConfirm: String
  }

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
    const select = this.actionTarget
    const action = select.value
    if (!action) {
      window.alert(this.chooseValue)
      return
    }

    const acronyms = this.selectedAcronyms()
    if (acronyms.length === 0) {
      window.alert(this.selectValue)
      return
    }

    if (!window.confirm(this.#confirmMessage(action, select.selectedOptions[0].text, acronyms))) return

    const body = new URLSearchParams()
    body.append("ontologies", acronyms.join(","))
    if (action !== "delete") body.append("actions", action)

    const data = await this.#request(this.processUrlValue, action === "delete" ? "DELETE" : "PUT", body)
    this.#showMessage(data)
    this.#reloadFrame()
  }

  async refresh(event) {
    event.preventDefault()
    if (!window.confirm(this.refreshConfirmValue)) return

    const previousDate = this.reportDateTarget.textContent.trim()
    this.refreshButtonTarget.disabled = true

    const data = await this.#request(this.refreshUrlValue, "POST", new URLSearchParams())
    this.#showMessage(data)
    if (data.errors && data.errors.length) {
      this.refreshButtonTarget.disabled = false
      return
    }

    await this.#waitForNewReport(previousDate)
    this.#reloadFrame()
  }

  async #waitForNewReport(previousDate) {
    for (let attempt = 0; attempt < POLL_MAX_ATTEMPTS; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS))
      const response = await fetch(this.reportUrlValue, { cache: "no-store", headers: { "Accept": "application/json" } })
      const report = await response.json().catch(() => ({}))
      if (report.report_date_generated && report.report_date_generated !== previousDate) return
    }
  }

  #confirmMessage(action, label, acronyms) {
    const list = acronyms.join(", ")
    if (action === "delete") {
      return `${this.deleteLeadValue}\n${list}\n\n${this.cannotUndoValue}`
    }
    return `${this.procLeadValue.replace("%{operation}", label)}\n${list}\n\n${this.procQueueValue}\n${this.proceedValue}`
  }

  async #request(url, method, body) {
    const response = await fetch(url, {
      method,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": this.#csrfToken()
      },
      body: body.toString()
    })
    return response.json().catch(() => ({}))
  }

  #showMessage(data) {
    const box = document.getElementById("admin_ontologies_messages")
    if (!box) return
    const failed = data.errors && data.errors.length
    const text = failed ? data.errors : (data.success || "")
    if (!text) return
    box.innerHTML = ""
    const alert = document.createElement("div")
    alert.className = `alert alert-${failed ? "danger" : "success"}`
    alert.setAttribute("role", "alert")
    alert.textContent = text
    box.appendChild(alert)
  }

  #reloadFrame() {
    const frame = this.element.closest("turbo-frame")
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
