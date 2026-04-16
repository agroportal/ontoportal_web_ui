import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="subscribe-notes"
export default class extends Controller {
    static values = {
        ontologyId: String,
        isSubbed: Boolean,
        userId: String,
        watch: String,
        unwatch: String,
        subscriptionId: String,
        notificationType: Number
    }
    static targets = ["error", "loader", "text", "count", "chevronContainer", "optionsContainer", "typeOption", "tick"]

    subscribeToNotes() {
        let ontologyId = this.ontologyIdValue
        let isSubbed = this.isSubbedValue

        this.#hideError()
        this.#showSpinner()

        const bpConfig = jQuery(document).data().bp.config
        const apiKey = bpConfig.userapikey

        let apiUrl = bpConfig.rest_url + "/subscriptions"
        let method = "POST"

        if (isSubbed) {
            method = "DELETE"
            apiUrl += "/" + this.subscriptionIdValue
        }

        fetch(apiUrl, {
            method: method,
            headers: {
                "Authorization": "apikey token=" + apiKey,
                "Content-Type": "application/json",
                "Cache-Control": "no-cache"
            },
            body: isSubbed ? null : JSON.stringify({
                ontology: ontologyId,
                notification_type: 3
            })
        })
            .then(response => {
                this.#hideSpinner()

                if (!response.ok) {
                    this.#showError()
                    return
                }

                // For POST requests, the API returns the created object.
                // For DELETE requests, it is usually empty or returns 204.
                return response.status === 204 ? {} : response.json()
            })
            .then(data => {
                if (!data) return;

                this.isSubbedValue = !isSubbed

                // Update subscriptionIdValue if we just created one
                const newId = data['@id'] || data.id
                if (!isSubbed && newId) {
                    const idStr = newId.toString()
                    this.subscriptionIdValue = idStr.includes('/') ? idStr.split('/').pop() : idStr
                    this.notificationTypeValue = 3
                    this.#showOptions()
                } else if (isSubbed) {
                    this.subscriptionIdValue = ""
                    this.#hideOptions()
                }

                // Change button text
                let txt = this.textTarget.innerHTML
                let count = parseInt(this.countTarget.innerHTML)

                let newButtonText = txt.match(this.unwatchValue) ? txt.replace(this.unwatchValue, this.watchValue) : txt.replace(this.watchValue, this.unwatchValue);
                this.element.setAttribute('title', newButtonText + ' this ontology')
                this.textTarget.innerHTML = newButtonText
                this.countTarget.innerHTML = newButtonText.match(this.unwatchValue) ? (count + 1) : (count - 1)
            })
            .catch(() => {
                this.#hideSpinner()
                this.#showError()
            })
    }

    changeNotificationType(event) {
        event.preventDefault()
        const newType = parseInt(event.currentTarget.dataset.value)

        this.#hideError()
        this.#showSpinner()

        const bpConfig = jQuery(document).data().bp.config
        const apiKey = bpConfig.userapikey
        const apiUrl = `${bpConfig.rest_url}/subscriptions/${this.subscriptionIdValue}`

        fetch(apiUrl, {
            method: "PATCH",
            headers: {
                "Authorization": "apikey token=" + apiKey,
                "Content-Type": "application/json",
                "Cache-Control": "no-cache"
            },
            body: JSON.stringify({
                notification_type: newType
            })
        })
            .then(response => {
                this.#hideSpinner()
                if (!response.ok) {
                    this.#showError()
                    return
                }
                this.notificationTypeValue = newType
                this.#updateActiveTypeHighlight(newType)
            })
            .catch(() => {
                this.#hideSpinner()
                this.#showError()
            })
    }

    #updateActiveTypeHighlight(type) {
        this.typeOptionTargets.forEach(el => {
            const tick = el.querySelector("[data-subscribe-notes-target='tick']")
            if (parseInt(el.dataset.value) === type) {
                el.classList.add("active-subscription")
                if (tick) tick.style.visibility = "visible"
            } else {
                el.classList.remove("active-subscription")
                if (tick) tick.style.visibility = "hidden"
            }
        })
    }

    #showOptions() {
        const type = this.notificationTypeValue || 3
        this.optionsContainerTarget.innerHTML = `
            <a class="dropdown-item d-flex align-items-center ${type === 1 ? 'active-subscription' : ''}" href="#" data-action="click->subscribe-notes#changeNotificationType" data-value="1" data-subscribe-notes-target="typeOption">
                <i class="fas fa-check mr-2" data-subscribe-notes-target="tick" style="visibility: ${type === 1 ? 'visible' : 'hidden'};"></i>
                Notes only
            </a>
            <a class="dropdown-item d-flex align-items-center ${type === 2 ? 'active-subscription' : ''}" href="#" data-action="click->subscribe-notes#changeNotificationType" data-value="2" data-subscribe-notes-target="typeOption">
                <i class="fas fa-check mr-2" data-subscribe-notes-target="tick" style="visibility: ${type === 2 ? 'visible' : 'hidden'};"></i>
                Processing status Only
            </a>
            <a class="dropdown-item d-flex align-items-center ${type === 3 ? 'active-subscription' : ''}" href="#" data-action="click->subscribe-notes#changeNotificationType" data-value="3" data-subscribe-notes-target="typeOption">
                <i class="fas fa-check mr-2" data-subscribe-notes-target="tick" style="visibility: ${type === 3 ? 'visible' : 'hidden'};"></i>
                All
            </a>
            <div class="dropdown-divider"></div>
        `
    }

    #hideOptions() {
        this.optionsContainerTarget.innerHTML = ""
    }

    #showSpinner() {
        $(this.loaderTarget).show()
    }

    #hideSpinner() {
        $(this.loaderTarget).hide()
    }


    #showError() {
        const errorElem = $(this.errorTarget)
        errorElem.html("Problem updating subscription, please try again")
        errorElem.show()
    }

    #hideError() {
        $(this.errorTarget).hide()
    }


}
