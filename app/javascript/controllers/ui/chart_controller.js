import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--chart'
export default class extends Controller {
  // Chartkick's inline script waits on the chartkick:load event chartkick.js dispatches
  // when it arrives, so it can load this late. Chart.bundle first, or chartkick dispatches
  // with no adapter.
  async connect () {
    try {
      await import('Chart.bundle')
      await import('chartkick')
    } catch {
      // A module fetch the network dropped - the chart stays blank, and there's nothing to report
    }
  }
}
