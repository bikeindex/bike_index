import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--chart'
export default class extends Controller {
  // Chartkick's inline script waits on the chartkick:load event that chartkick.js
  // dispatches when it arrives, so loading it here rather than from application.js keeps
  // 180KB gzipped off every page without one. Chart.bundle first, so chartkick finds an
  // adapter; concurrent connects dedupe through the browser's module map.
  async connect () {
    if (window.Chartkick) return

    await import('Chart.bundle')
    await import('chartkick')
  }
}
