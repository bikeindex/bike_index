import { Controller } from '@hotwired/stimulus'
import { replaceUrl } from 'bikebook/replace_url'

// Connects to data-controller='bikebook--schema-fields'
// Keeps ?open= and ?by_count= naming the folded objects and enums opened, and which of those order by count,
// so the server renders them that way again
export default class extends Controller {
  write () {
    const url = new URL(window.location)
    this.setParam(url, 'open', [...this.element.querySelectorAll('details[open][data-schema-path]')]
      .map((element) => element.dataset.schemaPath))
    this.setParam(url, 'by_count', [...this.element.querySelectorAll('[data-schema-by-count]:checked')]
      .filter((element) => element.closest('details').open)
      .map((element) => element.dataset.schemaByCount))
    replaceUrl(url)
  }

  setParam (url, name, paths) {
    paths.length ? url.searchParams.set(name, paths.join(',')) : url.searchParams.delete(name)
  }
}
