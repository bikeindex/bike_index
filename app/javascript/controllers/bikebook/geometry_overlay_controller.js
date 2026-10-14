import { Controller } from '@hotwired/stimulus'

// The drawing's and each vehicle's frame's attributes as last drawn, which the next drawing moves the same ones from
let drawn = new Map()
const ATTRIBUTES = { svg: ['viewBox'], g: ['transform'], circle: ['cx', 'cy', 'r'], path: ['d'] }
const NUMBER = /-?\d*\.?\d+(?:e[-+]?\d+)?/gi
const DURATION = 400
const easeInOut = (progress) => progress < 0.5 ? 4 * progress ** 3 : 1 - (-2 * progress + 2) ** 3 / 2

// Connects to data-controller='bikebook--geometry-overlay'
// A legend button fades the other frames and draws its own over them, until it's pressed again. A frame redrawn in
// another size moves there from the last
export default class extends Controller {
  static targets = ['frame', 'button', 'top']

  connect () {
    this.#moveFrom(drawn)
  }

  disconnect () {
    cancelAnimationFrame(this.animation)
    drawn = new Map(this.#parts().map(([key, elements]) => [key, elements.map((element) => ATTRIBUTES[element.tagName].map((name) => element.getAttribute(name)))]))
  }

  toggle ({ currentTarget }) {
    const pressed = currentTarget.getAttribute('aria-pressed') !== 'true'
    const index = this.buttonTargets.indexOf(currentTarget)
    this.buttonTargets.forEach((button) => button.setAttribute('aria-pressed', pressed && button === currentTarget))
    this.frameTargets.forEach((frame, each) => pressed && each !== index ? frame.setAttribute('opacity', '0.2') : frame.removeAttribute('opacity'))
    pressed ? this.topTarget.setAttribute('href', `#${this.frameTargets[index].id}`) : this.topTarget.removeAttribute('href')
  }

  #parts () {
    return [['drawing', [this.element.querySelector("svg[role='img']")].filter(Boolean)],
      ...this.frameTargets.map((frame) => [frame.dataset.vehicle, [frame, ...frame.querySelectorAll('circle, path')]])]
  }

  // Each attribute with as many numbers as it had, from those to its own
  #moveFrom (previous) {
    if (previous.size === 0 || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    const tweens = this.#parts().flatMap(([key, elements]) => {
      const before = previous.get(key)
      if (before?.length !== elements.length) return []
      return elements.flatMap((element, index) => ATTRIBUTES[element.tagName].flatMap((name, each) => {
        const [from, to] = [before[index][each], element.getAttribute(name)]
        const [start, end] = [from, to].map((value) => (value?.match(NUMBER) ?? []).map(Number))
        return from === to || start.length === 0 || start.length !== end.length ? [] : [{ element, name, to, start, end }]
      }))
    })
    if (tweens.length === 0) return

    const began = performance.now()
    const step = (now) => {
      const progress = Math.min((now - began) / DURATION, 1)
      for (const { element, name, to, start, end } of tweens) {
        let index = 0
        element.setAttribute(name, progress === 1
          ? to
          : to.replace(NUMBER, () => {
            const value = start[index] + (end[index] - start[index]) * easeInOut(progress)
            index++
            return value.toFixed(2)
          }))
      }
      if (progress < 1) this.animation = requestAnimationFrame(step)
    }
    this.animation = requestAnimationFrame(step)
  }
}
