import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.current = 0
    this.updateArrows()
  }

  prev() {
    if (this.current > 0) {
      this.current--
      this.slideTo(this.current)
    }
  }

  next() {
    if (this.current < this.containerTarget.children.length - 1) {
      this.current++
      this.slideTo(this.current)
    }
  }

  slideTo(index) {
    this.containerTarget.style.transform = `translateX(-${index * 100}%)`
    this.updateArrows()
  }

  updateArrows() {
    const max = this.containerTarget.children.length - 1
    const prevBtn = this.element.querySelector(".fairness-carousel-btn-prev")
    const nextBtn = this.element.querySelector(".fairness-carousel-btn-next")
    if (prevBtn) prevBtn.classList.toggle("disabled", this.current === 0)
    if (nextBtn) nextBtn.classList.toggle("disabled", this.current >= max)
  }
}
