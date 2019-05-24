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

  setEventListeners () {
    this.$form.on("click", "#js-organization-type input.form-check-input", e => {
      this.toggleAmbassadorFields(e.target);
    });
  }

  toggleAmbassadorFields(target) {
    const inputFields = [
      'organization_ascend_name',
      'organization_website',
      "organization_parent_organization_id",
      "organization_show_on_map",
      "organization_lock_show_on_map",
      "organization_api_access_approved",
      "organization_approved"
    ].map(fieldId => {
      return {
        element: this.$form.find(`#${fieldId}`),
        label: this.$form.find(`label[for='${fieldId}']`)
      };
    });

    const selectizedFields = [
      "organization_parent_organization_id"
    ].map(fieldId => {
      return {
        element: this.$form.find(`#${fieldId}`),
        label: this.$form.find(`label[for='${fieldId}-selectized']`)
      };
    });

    const $orgType = $(target);
    const isAmbassadorOrgSelected = $orgType.val() === "ambassador";

    if (isAmbassadorOrgSelected) {
      this.disableFields({inputFields, selectizedFields});
    } else {
      this.enableFields({inputFields, selectizedFields});
    }
  }

  disableFields({ inputFields, selectizedFields }) {
    inputFields.forEach(field => {
      field.element.attr("disabled", true);
      field.label.addClass("text-muted");
    });

    selectizedFields.forEach(field => {
      field.element.selectize()[0].selectize.disable();
      field.label.addClass("text-muted");
    });
  }

  enableFields({ inputFields, selectizedFields }) {
    inputFields.forEach(field => {
      field.element.attr("disabled", false);
      field.label.removeClass("text-muted");
    });
    selectizedFields.forEach(field => {
      field.element.selectize()[0].selectize.enable();
      field.label.removeClass("text-muted");
    });
  }
}

export default OrganizationForm;
