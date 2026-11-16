import { Controller } from "@hotwired/stimulus"

// Disables the submit button of a bulk action until a row is checked
// Connects to data-controller="bulk-select"
export default class extends Controller {
    static targets = ["checkbox", "submit"]

    // Checkboxes may come back checked, e.g. on back navigation
    connect() {
        this.toggle()
    }

    toggle() {
        this.submitTarget.disabled = !this.checkboxTargets.some(checkbox => checkbox.checked)
    }
}
