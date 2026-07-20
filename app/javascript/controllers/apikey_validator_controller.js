import { Controller } from "@hotwired/stimulus"
import debounce from "debounce"

// Connects to data-controller="apikey-validator"
// Validates a federated portal apikey against the target portal API and shows,
// next to the apikey field, the same icons the resolvability check uses
// (loader while checking, success / error icon once resolved), so the admin
// gets feedback before saving the catalog configuration.
export default class extends Controller {
    static targets = ["api", "apikey", "checkingIcon", "validIcon", "invalidIcon"]
    static values = { url: String }

    static UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

    // Validate already filled-in keys (e.g. portals saved previously) so their
    // status shows as soon as the form opens.
    connect() {
        // Debounce so typing does not fire a request on every single keystroke.
        this.validate = debounce(this.validate.bind(this), 350)
        if (this.hasApikeyTarget && this.apikeyTarget.value.trim() !== "") {
            this.validate()
        }
    }

    validate() {
        const apikey = this.apikeyTarget.value.trim()
        const api = this.hasApiTarget ? this.apiTarget.value.trim() : ""

        if (apikey === "") {
            this.#render("")
            return
        }

        if (!this.constructor.UUID_REGEX.test(apikey)) {
            this.#render("invalid")
            return
        }

        this.#render("checking")

        const url = `${this.urlValue}?api=${encodeURIComponent(api)}&apikey=${encodeURIComponent(apikey)}`
        fetch(url, { headers: { "Accept": "application/json" } })
            .then(response => response.ok ? response.json() : Promise.reject(response.statusText))
            .then(data => this.#render(data.valid ? "valid" : "invalid"))
            .catch(() => this.#render(""))
    }

    #render(state) {
        this.#toggle(this.checkingIconTargets, state === "checking")
        this.#toggle(this.validIconTargets, state === "valid")
        this.#toggle(this.invalidIconTargets, state === "invalid")
    }

    #toggle(targets, show) {
        targets.forEach(el => el.style.display = show ? "inline-flex" : "none")
    }
}
