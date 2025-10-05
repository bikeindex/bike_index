import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='infinite-scroll'
export default class extends Controller {
  static targets = ['pagination']
  static values = {
    threshold: { type: Number, default: 300 }
  }

  connect () {
    this.observer = new IntersectionObserver(
      entries => this.handleIntersection(entries),
      {
        root: null,
        rootMargin: `${this.thresholdValue}px`,
        threshold: 0
      }
    )

    if (this.hasPaginationTarget) {
      this.observer.observe(this.paginationTarget)
    }
  }

  disconnect () {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  handleIntersection (entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const nextPageLink = this.paginationTarget.querySelector('a[rel="next"]')
        if (nextPageLink) {
          nextPageLink.click()
        }
      }
    })
  }

  paginationTargetConnected () {
    if (this.observer) {
      this.observer.observe(this.paginationTarget)
    }
  }

  paginationTargetDisconnected () {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
