import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='recovery-stories--translate-quote'
// Machine-translates an English quote through the endpoint Google's browser extension
// uses - unauthenticated, so it rate limits after a few pages. A failure leaves the English
export default class extends Controller {
  static targets = ['quote', 'credit']
  static values = { locale: String }

  async connect () {
    if (this.localeValue === 'en') return

    const query = new URLSearchParams({ client: 'gtx', sl: 'en', tl: this.localeValue, dt: 't', q: this.quoteTarget.textContent.trim() })
    try {
      const response = await fetch(`https://translate.googleapis.com/translate_a/single?${query}`)
      const [sentences] = await response.json()
      this.quoteTarget.textContent = sentences.map(([translated]) => translated).join('')
      this.creditTarget.hidden = false
    } catch {}
  }
}
