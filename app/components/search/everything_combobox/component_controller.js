import { Controller } from '@hotwired/stimulus'
import "jquery"
import "select2"

// Connects to data-controller='search--everything-combobox--component'
export default class extends Controller {
  connect() {
    // remove the query field that is for users that don't have JS and show the combobox
    document.querySelectorAll(".remove_when_js_available").forEach(el => {if(!!el) el.remove()})
    this.element.classList.remove("tw:hidden")

    // TODO:
    //   Can switch to using jquery without preload, by checking if it's loaded first?
    this.initializeHeaderSearch($(this.element));
  }

  initializeHeaderSearch($query_field) {
    const per_page = 15;

    // TODO: Find this dynamically? Set it at a higher level?
    const searchFormSelector = '#Search_Form'

    const initial_opts = $query_field.data('initial') ? $query_field.data('initial') : [];
    const processedResults = this.processedResults; // Custom data processor
    const formatSearchText = this.formatSearchText; // Custom formatter


    const $desc_search = $query_field.select2({
      allowClear: true,
      tags: true,
      multiple: true,
      openOnEnter: false,
      tokenSeparators: [','],
      placeholder: $query_field.attr('placeholder'), // Pull placeholder from HTML
      // dropdownParent: $(searchFormSelector), // Append to search for for easier css access
      templateResult: formatSearchText, // let custom formatter work
      // selectOnClose: true // Turned off in PR#2325
      escapeMarkup: function(markup) { return markup; }, // Allow our fancy display of options
      ajax: {
        url: '/api/autocomplete',
        dataType: 'json',
        delay: 150,
        data: function(params) {
          return {
            q: params.term,
            page: params.page,
            per_page: per_page,
            categories: window.searchBarCategories
          };
        },
        processResults: function(data, page) {
          return {
            results: processedResults(data.matches),
            pagination: {
              // If exactly per_page matches there's likely at another page
              more: data.matches.length == per_page
            }
          };
        },
        cache: true
      }
    });

    // Submit on enter. Requires select2 be appended to bike-search form (as it is)
    // window.bike_search_submit = true
    $(`${searchFormSelector} .select2-selection`).on('keyup', function(e) {
      // Only trigger submit on enter if:
      //  - Enter key pressed last (13)
      //  - Escape key pressed last (27)
      //  - no keys have been pressed (selected with the mouse, instantiated true)
      if (e.keyCode == 27) return window.bike_search_submit = true;
      if (e.keyCode != 13) return window.bike_search_submit = false;

      if (window.bike_search_submit) {
        $desc_search.select2('close'); // Because form is submitted, hide select box
        $(searchFormSelector).submit();
      } else {
        window.bike_search_submit = true;
      }
    });

    // Every time the select changes, check the categories
    $query_field.on('change', (e) => {
      this.setCategories($query_field);
    });
  }

  processedResults(items) {
    return items.map(function(item) {
      if (typeof item === 'string') return { id: item, text: item };
      return {
        id: item.search_id,
        text: item.text,
        category: item.category,
        display: item.display
      };
    });
  }

  formatSearchText(item) {
    if (item.loading) return item.text;
    if (item.category == 'propulsion') return "<span>Search for <strong>" + item.text + "</strong> only</span>";
    if (item.category == 'cycle_type') return "<span>Search only for <strong>" + item.text + "</strong></span>";

    let prefix;
    switch (item.category) {
      case 'colors':
        let p = "<span class='sch_'>Bikes that are </span>";
        if (item.display) {
          prefix = p + "<span class='sclr' style='background: " + item.display + ";'></span>";
        } else {
          prefix = p + "<span class='sclr'>stckrs</span>";
        }
        break;
      case 'cycle_type':
        prefix = "<span class='sch_'>only for</span>";
        break;
      case 'cmp_mnfg':
      case 'frame_mnfg':
        prefix = "<span class='sch_'>Bikes made by</span>";
        break;
      default:
        prefix = 'Search for';
    }

    return prefix + " <span class='label'>" + item.text + '</span>';
  }

  // Don't include manufacturers if a manufacturer is selected
  setCategories($query_field) {
    let query = $query_field.val();
    if (!query) query = []; // Assign query to an array if it's blank

    let queried_categories = query.filter(function(x) {
      return /^(v|m)_/.test(x);
    }).map(function(i) {
      return i.split("_")[0];
    });

    if (queried_categories.length === 0) {
      window.searchBarCategories = "";
    } else {
      window.searchBarCategories = "colors";

      if (!queried_categories.includes("v")) {
        window.searchBarCategories += ",cycle_type";
      }

      if (!queried_categories.includes("m")) {
        window.searchBarCategories += ",frame_mnfg,cmp_mnfg";
      }

      if (!queried_categories.includes("p")) {
        window.searchBarCategories += ",propulsion";
      }
    }
  }
}
