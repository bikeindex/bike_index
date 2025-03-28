import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--targeting-fields--component'
export default class extends Controller {
  static values = { apiCountUrl: String }

  connect() {
    console.log('---->', this.apiCountUrlValue)
    console.log(window.interpreted_params)
  }

  setSearchTabInfo(location, url) {
    document.getElementById('search_distance').textContent = document.getElementById('distance').value;
    document.getElementById('search_location').textContent = location;

    const search_data = Object.assign({}, window.interpreted_params, { location: location });

    fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
      body: new URLSearchParams(search_data)
    })
    .then(response => response.json())
    .then(data => {
      this.insertTabCounts(data);
    });
  }

  displayedCountNumber(number) {
    if (number > 999) {
      if (number > 9999) {
        number = '10k+';
      } else {
        number = `${String(number).charAt(0)}k+`;
      }
    }
    return `(${number})`;
  }

  insertTabCounts(counts) {
    for (const stolenness of Object.keys(counts)) {
      const count = this.displayedCountNumber(counts[stolenness]);
      document.querySelector(`#stolenness_tab_${stolenness} .count`).textContent = count;
    }
  }
}
