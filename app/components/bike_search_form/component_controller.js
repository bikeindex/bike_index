import { Controller } from '@hotwired/stimulus'
import Choices from "choices.js"

// Connects to data-controller='bike-search-form--component'
export default class extends Controller {

  connect() {
    const per_page = 15;
    const queryField = document.querySelector('#query_items');
    this.searchBarCategories = this.setCategories()
    console.log(this.searchBarCategories)

    this.choices = new Choices(queryField, {
      removeItemButton: true,
      duplicateItemsAllowed: false,
      delimiter: ',',
      renderChoiceLimit: -1,
      addItems: true
    })

    // this.choices.setChoices(async () => {
    //   try {
    //     const items = await fetch(`/api/autocomplete?q=${encodeURIComponent(event.detail.value)}&page=1&per_page=${per_page}&categories=${this.searchBarCategories}`);
    //     return items.json();
    //   } catch (err) {
    //     console.error(err);
    //   }
    // })

    window.choicesSearchTimeout = setTimeout(() => {
      fetch(`/api/autocomplete?q=${encodeURIComponent(event.detail.value)}&page=1&per_page=${per_page}&categories=${window.searchBarCategories}`)
        .then(response => response.json())
        .then(data => {

          // Format the choices for Choices.js
          const formattedChoices = data.matches.map(item => ({
            value: item.id,
            label: item.text,
            customProperties: item // Store the full item for custom rendering if needed
          }));

          // Add the choices to the dropdown
          $desc_search.setChoices(formattedChoices, 'value', 'label', true);

          // If you need pagination, you'll need to implement it differently
          // Choices.js doesn't have built-in pagination like Select2
        })
        .catch(error => console.error('Error fetching autocomplete data:', error));
    }, 150); // Same delay as in the original
  }

  setCategories() {
    const queryField = document.querySelector('#query_items');
    let query = queryField ? queryField.value : null;
    if (!query) {
      query = [];  // Assign query to an array if it's blank
    }

    let queried_categories = query.filter(function(x) {
      return /^(v|m)_/.test(x);
    }).map(function(i) {
      return i.split("_")[0];
    });

    if (queried_categories.length === 0) {
      return "";
    } else {
      let categories = "colors";

      if (!queried_categories.includes("v")) {
        categories += ",cycle_type";
      }

      if (!queried_categories.includes("m")) {
        categories += ",frame_mnfg,cmp_mnfg";
      }

      if (!queried_categories.includes("p")) {
        categories += ",propulsion";
      }

      return categories;
    }
  }
}
