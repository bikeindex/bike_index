import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--combobox-state'
// The gem keeps its options in order and matches anywhere in "Oregon (OR)", then autocompletes the
// first shown - so "or" would pick California. Reordering ahead of its filter, in the capture phase,
// puts the abbreviation first, then names starting with the query, then words starting with it
export default class extends Controller {
  connect () {
    this.element.addEventListener('input', this.rank, true)
  }

  disconnect () {
    this.element.removeEventListener('input', this.rank, true)
  }

  rank = ({ target }) => {
    const query = target.value.trim().toLowerCase()
    this.element.querySelectorAll('[role=listbox]').forEach((listbox) => {
      const options = [...listbox.querySelectorAll(':scope > [role=option]')]
      options.sort((a, b) => score(a, query) - score(b, query) || a.dataset.index - b.dataset.index)
        .forEach((option) => listbox.append(option))
    })
  }

  // the server's alphabetical order, to fall back on
  initialize () {
    this.element.querySelectorAll('[role=listbox]').forEach((listbox) => {
      listbox.querySelectorAll(':scope > [role=option]').forEach((option, index) => { option.dataset.index = index })
    })
  }
}

function score (option, query) {
  const name = option.textContent.trim().toLowerCase()
  if (!query) return 0
  if (option.dataset.value.toLowerCase() === query) return 0
  if (name.startsWith(query)) return 1
  if (name.split(/\s+/).some((word) => word.startsWith(query))) return 2
  return 3
}
