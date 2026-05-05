import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "searchWrapper"]
  static values = {
    namePrefix: String,
    rowClass: { type: String, default: "nested-class-picker-form-input-row" }
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

    const visibleInput = document.createElement("input")
    visibleInput.type = "text"
    visibleInput.name = `${namePrefix}[${nextIndex}]`
    visibleInput.value = label
    visibleInput.readOnly = true
    visibleInput.className = "form-control"
    visibleInput.style.fontSize = "13px"

    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = `${namePrefix}[${nextIndex}]`
    hiddenInput.value = uri

    const row = document.createElement("div")
    row.className = rowClass
    row.appendChild(visibleInput)
    row.appendChild(hiddenInput)

    this.element.appendChild(row)

    if (this.hasSearchWrapperTarget) {
      this.searchWrapperTarget.remove()
    }
  }
}
