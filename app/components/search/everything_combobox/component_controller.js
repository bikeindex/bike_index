import { Controller } from '@hotwired/stimulus'
import 'jquery'
import 'select2'

/* global $ */
// Connects to data-controller='search--everything-combobox--component'
export default class extends Controller {
  connect () {
    // remove the query field that is for users that don't have JS and show the combobox
    document.querySelectorAll('.remove_when_js_available').forEach(el => { if (el) el.remove() })
    this.element.classList.remove('tw:hidden')

    // TODO:
    //   Can switch to using jquery without preload, by checking if it's loaded first?
    this.initializeHeaderSearch($(this.element))
  }

  initializeHeaderSearch ($queryField) {
    const perPage = 15

    // TODO: Find this dynamically? Set it at a higher level?
    const searchFormSelector = '#Search_Form'

    const processedResults = this.processedResults // Custom data processor
    const formatSearchText = this.formatSearchText // Custom formatter

    const $descSearch = $queryField.select2({
      allowClear: true,
      tags: true,
      multiple: true,
      openOnEnter: false,
      tokenSeparators: [','],
      placeholder: $queryField.attr('placeholder'), // Pull placeholder from HTML
      // dropdownParent: $(searchFormSelector), // Append to search for for easier css access
      templateResult: formatSearchText, // let custom formatter work
      // selectOnClose: true // Turned off in PR#2325
      escapeMarkup: function (markup) { return markup }, // Allow our fancy display of options
      ajax: {
        url: '/api/autocomplete',
        dataType: 'json',
        delay: 150,
        data: function (params) {
          return {
            q: params.term,
            page: params.page,
            per_page: perPage,
            categories: window.searchBarCategories
          }
        },
        processResults: function (data, page) {
          return {
            results: processedResults(data.matches),
            pagination: {
              // If exactly perPage matches there's likely at another page
              more: data.matches.length === perPage
            }
          }
        },
        cache: true
      }
    })

    // Submit on enter. Requires select2 be appended to bike-search form (as it is)
    // window.bike_search_submit = true
    $(`${searchFormSelector} .select2-selection`).on('keyup', function (e) {
      // Only trigger submit on enter if:
      //  - Enter key pressed last (13)
      //  - Escape key pressed last (27)
      //  - no keys have been pressed (selected with the mouse, instantiated true)
      if (e.keyCode === 27) {
        window.bike_search_submit = true
        return true
      }
      if (e.keyCode !== 13) {
        window.bike_search_submit = false
        return false
      }

      if (window.bike_search_submit) {
        $descSearch.select2('close') // Because form is submitted, hide select box
        $(searchFormSelector).submit()
      } else {
        window.bike_search_submit = true
      }
    })

    // Every time the select changes, check the categories
    $queryField.on('change', (e) => {
      this.setCategories($queryField)
    })
  }

  processedResults (items) {
    return items.map(function (item) {
      if (typeof item === 'string') return { id: item, text: item }
      return {
        id: item.search_id,
        text: item.text,
        category: item.category,
        display: item.display
      }
    })
  }

  formatSearchText (item) {
    if (item.loading) return item.text
    if (item.category === 'propulsion') return '<span>Search for <strong>' + item.text + '</strong> only</span>'
    if (item.category === 'cycle_type') return '<span>Search only for <strong>' + item.text + '</strong></span>'

    const getPrefix = () => {
      if (item.category === 'colors') {
        const p = "<span class='sch_'>Bikes that are </span>"
        if (item.display) {
          return p + "<span class='sclr' style='background: " + item.display + ";'></span>"
        } else {
          return p + "<span class='sclr'>stckrs</span>"
        }
      } else if (item.category === 'cycle_type') {
        return "<span class='sch_'>only for</span>"
      } else if (item.category === 'cmp_mnfg' || item.category === 'frame_mnfg') {
        return "<span class='sch_'>Bikes made by</span>"
      } else {
        return 'Search for'
      }
    }

    return getPrefix() + " <span class='label'>" + item.text + '</span>'
  }

  // Don't include manufacturers if a manufacturer is selected
  setCategories ($queryField) {
    let query = $queryField.val()
    if (!query) query = [] // Assign query to an array if it's blank

    const queriedCategories = query.filter(function (x) {
      return /^(v|m)_/.test(x)
    }).map(function (i) {
      return i.split('_')[0]
    })

    if (queriedCategories.length === 0) {
      window.searchBarCategories = ''
    } else {
      window.searchBarCategories = 'colors'

      if (!queriedCategories.includes('v')) {
        window.searchBarCategories += ',cycle_type'
      }

      if (!queriedCategories.includes('m')) {
        window.searchBarCategories += ',frame_mnfg,cmp_mnfg'
      }

      if (!queriedCategories.includes('p')) {
        window.searchBarCategories += ',propulsion'
      }
    }
  }
}
