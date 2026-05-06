import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "searchWrapper"]
  static values = {
    namePrefix: String,
    rowClass: { type: String, default: "nested-class-picker-form-input-row" },
    showUri: { type: Boolean, default: false }
  }

  addResult(event) {
    event.preventDefault()
    const target = event.currentTarget

    const uriSpan = target.querySelector('.class-uri')
    const labelSpan = target.querySelector('.class-label_name')
    if (!uriSpan || !labelSpan) return

    const uri = uriSpan.textContent.trim()
    const label = labelSpan.textContent.trim()

    const namePrefix = this.namePrefixValue
    const rowClass = this.rowClassValue
    const nextIndex = document.querySelectorAll(`.${rowClass}`).length

    const row = document.createElement("div")
    row.className = rowClass

    if (this.showUriValue) {
      const display = document.createElement("div")
      display.className = "class-picker-display"

      const labelEl = document.createElement("p")
      labelEl.className = "class-label_name"
      labelEl.textContent = label

      const uriEl = document.createElement("small")
      uriEl.className = "class-uri"
      uriEl.textContent = uri

      display.appendChild(labelEl)
      display.appendChild(uriEl)
      row.appendChild(display)
    } else {
      const visibleInput = document.createElement("input")
      visibleInput.type = "text"
      visibleInput.name = `${namePrefix}[${nextIndex}]`
      visibleInput.value = label
      visibleInput.readOnly = true
      visibleInput.className = "form-control"
      visibleInput.style.fontSize = "13px"
      row.appendChild(visibleInput)
    }

    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = `${namePrefix}[${nextIndex}]`
    hiddenInput.value = uri
    row.appendChild(hiddenInput)

    this.element.appendChild(row)

    if (this.hasSearchWrapperTarget) {
      this.searchWrapperTarget.remove()
    }
  }
}
