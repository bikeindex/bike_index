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
      const scores = new Map(options.map((option) => [option, score(option, query)]))
      // ties fall back to the alphabetical order the server rendered
      const ranked = options.toSorted((a, b) => scores.get(a) - scores.get(b) || a.textContent.localeCompare(b.textContent))
      if (ranked.some((option, index) => option !== options[index])) listbox.append(...ranked)
    })
  }
}

function score (option, query) {
  if (!query || option.dataset.value.toLowerCase() === query) return 0

  const name = option.textContent.trim().toLowerCase()
  if (name.startsWith(query)) return 1
  return name.split(/\s+/).some((word) => word.startsWith(query)) ? 2 : 3
}
