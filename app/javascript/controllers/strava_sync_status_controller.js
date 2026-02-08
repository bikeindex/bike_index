import { Controller } from '@hotwired/stimulus'

// Polls the Strava sync status endpoint and updates the progress display
// Connects to data-controller='strava-sync-status'
export default class extends Controller {
  static values = { url: String }

  connect () {
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
        if (data.status === 'syncing') {
          this.updateProgress(data)
          this.timer = setTimeout(() => this.poll(), 5000)
        } else if (data.status === 'synced' || data.status === 'error') {
          // Reload the page to show the final state
          window.location.reload()
        }
      })
      .catch(() => {
        // Retry after a longer delay on error
        this.timer = setTimeout(() => this.poll(), 10000)
      })
  }

  updateProgress (data) {
    const progressBar = this.element.closest('.side-box')?.querySelector('.progress-bar')
    if (progressBar) {
      progressBar.style.width = `${data.progress_percent}%`
      progressBar.textContent = `${data.progress_percent}%`
      progressBar.setAttribute('aria-valuenow', data.progress_percent)
    }

    // Update the downloaded count text
    const countEl = this.element.closest('.side-box')?.querySelector('.strava-download-count')
    if (countEl) {
      countEl.textContent = `${data.activities_downloaded_count} of ${data.athlete_activity_count || '?'} activities downloaded`
    }
  }
}
