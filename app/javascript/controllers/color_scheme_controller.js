import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { url: String }

  select (event) {
    this.apply(event.target.value)
    this.save(event.target.value)
  }

  apply (colorScheme) {
    window.colorSchemeQuery ||= window.matchMedia('(prefers-color-scheme: dark)')
    const query = window.colorSchemeQuery
    query.onchange = colorScheme === 'system' ? () => document.body.classList.toggle('dark', query.matches) : null
    document.body.classList.toggle('dark', colorScheme === 'dark' || (colorScheme === 'system' && query.matches))
  }

  save (colorScheme) {
    fetch(this.urlValue, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ user: { color_scheme: colorScheme } })
    })
  }
}
