import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='homepage--animate-count'
export default class extends Controller {
  static values = {
    target: Number,
    duration: { type: Number, default: 3000 },
    delay: { type: Number, default: 500 },
    prefix: { type: String, default: "" },
    suffix: { type: String, default: "" }
  }

  connect() {
    setTimeout(() => this.animate(), this.delayValue)
  }

  animate() {
    const increment = this.targetValue / (this.durationValue / 16) // 60fps
    let current = 0 // NOTE: Actual initial values are the final values, for SEO/no JS

    const timer = setInterval(() => {
      current += increment
      if (current >= this.targetValue) {
        current = this.targetValue
        clearInterval(timer)
      }

      this.element.textContent = `${this.prefixValue}${Math.floor(current).toLocaleString()}${this.suffixValue}`
    }, 16)
  }
}
