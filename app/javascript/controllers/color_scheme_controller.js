import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { url: String }

  select ({ target: { value } }) {
    const query = (window.colorSchemeQuery ||= window.matchMedia('(prefers-color-scheme: dark)'))
    query.onchange = () => document.body.classList.toggle('dark', value === 'dark' || (value === 'system' && query.matches))
    query.onchange()
    document.cookie = `color_scheme=${value}; path=/; max-age=31536000; samesite=lax`
    // The account page renders a second picker, in the footer
    document.querySelectorAll(`[data-controller~="color-scheme"] input[value="${value}"]`).forEach(input => { input.checked = true })
    if (!this.urlValue) return

    fetch(this.urlValue, {
      method: 'PATCH',
      headers: { Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content },
      body: new URLSearchParams({ 'user[color_scheme]': value })
    })
  }
}
