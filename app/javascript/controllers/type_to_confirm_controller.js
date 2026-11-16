import { Controller } from "@hotwired/stimulus"

// Enables a destructive submit once the expected text is typed, e.g. the
// acronym of the ontology to delete
// Connects to data-controller="type-to-confirm"
export default class extends Controller {
    static targets = ["input", "submit"]
    static values = { expected: String }

    // The input may come back filled, e.g. on back navigation
    connect() {
        this.check()
    }

    check() {
        this.submitTarget.disabled = this.inputTarget.value.trim() !== this.expectedValue
    }
}
