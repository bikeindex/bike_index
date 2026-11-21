import { Controller } from '@hotwired/stimulus'
import { replaceUrl } from 'bikebook/replace_url'

// Connects to data-controller='bikebook--schema-fields'
// Keeps ?open= and ?by_count= naming the folds open, and the enums among them ordered by count, so the server
// renders them that way again. One inside a closed fold isn't, since naming it would open that fold too
export default class extends Controller {
  write () {
    const url = new URL(window.location)
    const shown = (element) => !element.closest('details:not([open])')
    this.setParam(url, 'open', [...this.element.querySelectorAll('details[open][data-schema-path]')]
      .filter((element) => shown(element.parentElement)).map((element) => element.dataset.schemaPath))
    this.setParam(url, 'by_count', [...this.element.querySelectorAll('[data-schema-by-count]:checked')]
      .filter(shown).map((element) => element.dataset.schemaByCount))
    replaceUrl(url)
  }

  setParam (url, name, paths) {
    paths.length ? url.searchParams.set(name, paths.join(',')) : url.searchParams.delete(name)
  }
}
