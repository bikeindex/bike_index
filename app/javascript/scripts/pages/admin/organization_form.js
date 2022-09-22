class BinxAdminOrganizationForm {
  constructor ($form) {
    this.$form = $form

    this.toggleAmbassadorFields(
      $form.find('#js-organization-type select').val()
    )
    this.toggleStolenMessageArea()

    this.setEventListeners()
  }

  setEventListeners () {
    this.$form.on('change', '#js-organization-type select', e => {
      this.toggleAmbassadorFields($(e.target).val())
    })
    this.$form.on('change', '#organization_stolen_message_kind', e => {
      this.toggleStolenMessageArea()
    })
  }

  toggleStolenMessageArea () {
    if ($('#organization_stolen_message_kind').val() == 'area') {
      $('#areaField').collapse('show')
    } else {
      $('#areaField').collapse('hide')
    }
  }

  toggleAmbassadorFields (orgType) {
    const inputFields = [
      'organization_ascend_name',
      'organization_website',
      'organization_parent_organization_id',
      'organization_show_on_map',
      'organization_lock_show_on_map',
      'organization_api_access_approved',
      'organization_approved'
    ].map(fieldId => {
      return {
        element: this.$form.find(`#${fieldId}`),
        label: this.$form.find(`label[for='${fieldId}']`)
      }
    })

    const selectizedFields = ['organization_parent_organization_id'].map(
      fieldId => {
        return {
          element: this.$form.find(`#${fieldId}`),
          label: this.$form.find(`label[for='${fieldId}-selectized']`)
        }
      }
    )

    const isAmbassadorOrgSelected = orgType === 'ambassador'

    if (isAmbassadorOrgSelected) {
      this.disableFields({ inputFields, selectizedFields })
    } else {
      this.enableFields({ inputFields, selectizedFields })
    }
  }

  disableFields ({ inputFields, selectizedFields }) {
    inputFields.forEach(field => {
      field.element.attr('disabled', true)
      field.label.addClass('text-muted')
    })

    selectizedFields.forEach(field => {
      field.element.selectize()[0].selectize.disable()
      field.label.addClass('text-muted')
    })
  }

  enableFields ({ inputFields, selectizedFields }) {
    inputFields.forEach(field => {
      field.element.attr('disabled', false)
      field.label.removeClass('text-muted')
    })
    selectizedFields.forEach(field => {
      field.element.selectize()[0].selectize.enable()
      field.label.removeClass('text-muted')
    })
  }
}

export default BinxAdminOrganizationForm
