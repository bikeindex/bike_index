import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--chart'
export default class extends Controller {
  // Chartkick's inline script waits on the chartkick:load event chartkick.js dispatches
  // when it arrives, so it can load this late. Chart.bundle first, or chartkick dispatches
  // with no adapter; and not at all where something else already supplies a Chartkick --
  // admin's vendored legacy bundle does, and its charts have already drawn by now.
  async connect () {
    if (window.Chartkick) return

    await import('Chart.bundle')
    await import('chartkick')
  }
}
