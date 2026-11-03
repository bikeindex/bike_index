import { Controller } from '@hotwired/stimulus'

// Chart.js draws its own legend in one font, which can't make a total smaller than its name
const htmlLegend = {
  id: 'htmlLegend',
  afterUpdate (chart, _args, { prefix = '', round }) {
    const wrapper = chart.canvas.closest('[data-controller~="ui--chart"]')
    const legend = wrapper.querySelector('[data-chart-legend]')
    const { labels, onClick } = chart.options.plugins.legend

    legend.replaceChildren(...labels.generateLabels(chart).map((item, position) => {
      const button = wrapper.querySelector('template').content.firstElementChild.cloneNode(true)
      const [swatch, name, count] = button.children
      const total = legendItemTotal(chart, item)
      const digits = { minimumFractionDigits: round, maximumFractionDigits: round }

      swatch.style.backgroundColor = item.fillStyle
      swatch.style.borderColor = item.strokeStyle
      name.textContent = item.text
      name.classList.toggle('tw:line-through', item.hidden)
      count.textContent = `(${prefix}${total.toLocaleString('en-US', digits)})`
      button.setAttribute('aria-pressed', !item.hidden)
      button.addEventListener('click', (event) => {
        onClick.call(chart.legend, event, item, chart.legend)
        // The update it triggers replaces this button
        legend.children[position].focus()
      })
      return button
    }))
  }
}

// A pie's legend items are the slices of its one dataset
const legendItemTotal = (chart, { datasetIndex, index }) => index === undefined
  ? chart.data.datasets[datasetIndex].data.reduce((sum, value) => sum + value, 0)
  : chart.data.datasets[0].data[index]

// Connects to data-controller='ui--chart'
export default class extends Controller {
  // Chartkick's inline script waits on the chartkick:load event chartkick.js dispatches
  // when it arrives, so it can load this late. Chart.bundle first, or chartkick dispatches
  // with no adapter.
  async connect () {
    await import('Chart.bundle')
    window.Chart.register(htmlLegend)
    await import('chartkick')
  }
}
