import { Controller } from '@hotwired/stimulus'

// Polls the Strava sync status endpoint and updates the progress display
// Connects to data-controller='strava-sync-status'
export default class extends Controller {
  static values = { url: String }

  connect () {
    this.initialStatus = null
    this.poll()
  }

  disconnect () {
    if (this.timer) clearTimeout(this.timer)
  }

  poll () {
    fetch(this.urlValue, {
      headers: { Accept: 'application/json' }
    })
      .then(response => response.json())
      .then(data => {
        if (this.initialStatus === null) this.initialStatus = data.status
        if (data.status === 'syncing' || data.status === 'pending') {
          this.updateProgress(data)
          this.timer = setTimeout(() => this.poll(), 5000)
        } else if (data.status === 'synced' || data.status === 'error') {
          // Only reload if status changed from a non-final state
          if (this.initialStatus !== data.status) window.location.reload()
        }
      })
      .catch(() => {
        // Retry after a longer delay on error
        this.timer = setTimeout(() => this.poll(), 10000)
      })
  }

  updateProgress (data) {
    const countEl = document.getElementById('strava-download-count')
    if (countEl) {
      const fmt = (n) => n == null ? '?' : Number(n).toLocaleString()
      countEl.textContent = `${data.progress_percent}% (${fmt(data.activities_downloaded_count)} / ${fmt(data.athlete_activity_count)}) downloaded`
    }
  }
}
