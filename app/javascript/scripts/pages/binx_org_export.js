import moment from 'moment-timezone'

export default class BinxAppOrgExport {
  init () {
    let body_id = document.getElementsByTagName('body')[0].id

    if (body_id == 'organized_exports_new') {
      this.initNewForm()
    } else {
      this.reloadIfUnfinished()
    }
  }

  initNewForm () {
    // make the datetimefield expand, set the time
    $('.field-expander').on('click', e => {
      e.preventDefault()
      let $parent = $(e.target).parents('.form-group')
      $parent.find('.field-expander').slideUp('fast', function () {
        $parent.find('.collapsed-fields').slideDown('fast')
        $parent.find("input[type='datetime-local']").val(
          moment()
            .startOf('day')
            .format('YYYY-MM-DDTHH:mm')
        )
      })

      // If this is 'Add Specific Bikes to export' mark 'only include specific bikes' by default
      // (unless include partial registrations is checked)
      if ($(e.target).is('#addSpecificBikes') && !$('#include_partial_registrations').is(':checked')) {
        $('#export_only_custom_bike_ids').prop('checked', true).change()
      }
    })

    // make the datetimefield collapse, remove the time
    $('.field-collapser').on('click', e => {
      e.preventDefault()
      let $parent = $(e.target).parents('.form-group')
      $parent.find('.collapsed-fields').slideUp('fast', function () {
        $parent.find('.field-expander').slideDown('fast')
        $parent.find("input[type='datetime-local']").val('')
      })
    })

    // Show avery
    this.showOrHideAssignBikeCode()
    // and on future changes, trigger the update
    $('#export_avery_export, #export_assign_bike_codes').on('change', e => {
      this.showOrHideAssignBikeCode()
    })

    // Show onlyCustom
    this.showOrHideOnlyCustom()
    // and on future changes, trigger the update
    $('#export_only_custom_bike_ids').on('change', e => {
      this.showOrHideOnlyCustom()
    })
  }

  showOrHideAssignBikeCode () {
    let isAssignCodes = $('#export_avery_export, #export_assign_bike_codes').is(
      ':checked'
    )
    let isAvery = $('#export_avery_export').length

    if (isAssignCodes) {
      if (isAvery) {
        $('.hiddenOnAveryExport').slideUp('fast')
      }
      $('.shownOnAssignBikeCodes')
        .slideDown('fast')
        .css('display', 'flex')
    } else {
      if (isAvery) {
        $('.hiddenOnAveryExport')
          .slideDown('fast')
          .css('display', 'flex')
      }
      $('.shownOnAssignBikeCodes').slideUp('fast')
    }
  }

  showOrHideOnlyCustom () {
    let isOnlyCustom = $('#export_only_custom_bike_ids').is(':checked')
    if (isOnlyCustom) {
      $('#expandCustomBikeIds').slideDown('fast') // required if custom bike ids start assigned
      $('.hiddenOnOnlyCustom').slideUp('fast')
    } else {
      $('.hiddenOnOnlyCustom')
        .slideDown('fast')
        .css('display', 'flex')
    }
  }

  reloadIfUnfinished () {
    if (!$('#exportProgress').hasClass('finished')) {
      // Reload the page after 2 seconds unless the export is more than 5 minutes old - at which point we assume something is broken
      let created = parseInt($('#exportProgress').attr('data-createdat'))
      if (moment().unix() - created < 300) {
        setTimeout(() => {
          location.reload(true)
        }, 5000)
      }
    }
  }
}
