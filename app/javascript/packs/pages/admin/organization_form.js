class OrganizationForm {
  constructor($form) {
    this.$form = $form;

    const $selectedType =
          $form
          .find("#js-organization-type")
          .find("input:checked")
          .first()

    this.toggleAmbassadorFields($selectedType);

    this.setEventListeners();
  }

  toggleAmbassadorFields(target) {
    const inputFieldIds = [
      'organization_ascend_name',
      'organization_website',
      "organization_parent_organization_id",
      "organization_show_on_map",
      "organization_lock_show_on_map",
      "organization_api_access_approved",
      "organization_approved"
    ]
    const selectizedFieldIds = [
      "organization_parent_organization_id"
    ]

    const $orgType = $(target)
    const isAmbassadorOrgSelected = $orgType.val() === "ambassador"

    if (isAmbassadorOrgSelected) {
      inputFieldIds
        .forEach(fieldId => {
          this.$form.find(`#${fieldId}`).attr("disabled", true)
          this.$form.find(`label[for='${fieldId}']`).addClass("text-muted")
        })
      selectizedFieldIds
        .forEach(fieldId => {
          this.$form.find(`#${fieldId}`).selectize()[0].selectize.disable()
          this.$form.find(`label[for='${fieldId}-selectized']`).addClass("text-muted")
        })
    } else {
      inputFieldIds
        .forEach(fieldId => {
          this.$form.find(`#${fieldId}`).attr("disabled", false)
          this.$form.find(`label[for='${fieldId}']`).removeClass("text-muted")
        })
      selectizedFieldIds
        .forEach(fieldId => {
          this.$form.find(`#${fieldId}`).selectize()[0].selectize.enable()
          this.$form.find(`label[for='${fieldId}-selectized']`).removeClass("text-muted")
        })
    }
  }

  setEventListeners () {
    this.$form.on("click", "#js-organization-type input.form-check-input", e => {
      this.toggleAmbassadorFields(e.target)
    })
  }
}

export default OrganizationForm;
