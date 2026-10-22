import { Controller } from '@hotwired/stimulus'
import { typeDetails } from 'bikebook/cycle_drawings'

// Connects to data-controller='admin--cycle-type-details'
// After each type's row, a copy for each type_detail the drawings draw their own way, drawn for that detail and its
// model in `examples`, which are keyed type/type_detail
export default class extends Controller {
  static targets = ['row']
  static values = { examples: Object }

  connect () {
    this.rowTargets.forEach((row) => typeDetails(row.dataset.type).toReversed().forEach((detail) => row.after(this.#detailRow(row, detail))))
  }

  #detailRow (row, detail) {
    const { type } = row.dataset
    const copy = row.cloneNode(true)
    copy.removeAttribute('data-admin--cycle-type-details-target')
    if (copy.hasAttribute('data-ui--collapse-param-value')) copy.setAttribute('data-ui--collapse-param-value', `${type}_${detail}`)
    const label = Object.assign(document.createElement('span'), { className: 'tw:text-xs', textContent: 'type detail: ' })
    label.append(Object.assign(document.createElement('code'), { className: 'tw:whitespace-nowrap', textContent: detail }))
    copy.querySelector('th code').after(document.createElement('br'), label)

    const [typicalCell, exampleCell] = copy.querySelectorAll('td')
    const typical = typicalCell.querySelector('[data-controller="admin--cycle-drawing"]')
    typical.replaceChildren()
    typical.setAttribute('data-admin--cycle-drawing-type-detail-value', detail)
    const model = this.examplesValue[`${type}/${detail}`]
    if (!model) {
      exampleCell.replaceChildren(Object.assign(document.createElement('span'), { className: 'tw:text-gray-500', textContent: 'No catalog models' }))
      return copy
    }
    const example = typical.cloneNode()
    example.setAttribute('data-admin--cycle-drawing-model-value', model)
    // a collapsed row's drawings sit in its collapse's content, which the example's takes a copy of
    const holder = typical.parentElement === typicalCell ? null : typical.parentElement.cloneNode()
    holder?.append(example)
    exampleCell.replaceChildren(holder ?? example)
    return copy
  }
}
