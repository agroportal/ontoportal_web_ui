import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="synonyms"
// Opens/closes an accessible <dialog> holding the full list of synonyms.
// The native <dialog> gives us focus trapping, Esc-to-close and focus
// restoration for free; the trigger is a real <button> so Enter / Space work.
export default class extends Controller {
  static targets = ['dialog']

  open (event) {
    if (event) event.preventDefault()
    if (!this.hasDialogTarget) return

    if (typeof this.dialogTarget.showModal === 'function') {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute('open', '')
    }
  }

  close () {
    if (!this.hasDialogTarget) return

    if (typeof this.dialogTarget.close === 'function') {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute('open')
    }
  }

  // Close when the click lands on the dialog element itself (the backdrop),
  // i.e. outside the inner panel.
  backdropClose (event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
