import { Controller } from '@hotwired/stimulus'
/* global ResizeObserver */

// Connects to data-controller='bikebook--wrapped-scroll'
// Once the vehicle cards wrap onto more than one row, caps each panel at 75% of
// the viewport height and scrolls it within its own frame, so every card's top
// stays reachable. The scroll sits on the bordered panel, not the bare row child,
// so a space-taking scrollbar doesn't inset the card.
export default class extends Controller {
  connect () {
    this.observer = new ResizeObserver(() => this.update())
    this.observer.observe(this.element)
    this.update()
  }

  disconnect () {
    this.observer.disconnect()
  }

  update () {
    const cards = Array.from(this.element.children)
    const wrapped = new Set(cards.map((card) => Math.round(card.getBoundingClientRect().top))).size > 1
    cards.forEach((card) => {
      const panel = card.querySelector('article') ?? card
      panel.classList.toggle('tw:max-h-[75vh]', wrapped)
      panel.classList.toggle('tw:overflow-y-auto', wrapped)
    })
  }
}
