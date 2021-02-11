import log from "../utils/log";

export default class BinxAppOrgImpoundRecords {
  constructor() {
    this.indexView =
      document.getElementsByTagName("body")[0].id ===
      "organized_impound_records_index";
  }

  init() {
    if (this.indexView) {
      this.initializeIndex();
    }
    // Always initialize edit, because multi update on index
    this.initializeEdit();
  }

  initializeIndex() {
    // Call the existing coffeescript class that manages the bike searchbar
    new BikeIndex.BikeSearchBar();

    // We're letting bootstrap handle the collapsing of the row, make sure to not block
    $("#toggleMultiUpdate").on("click", function (e) {
      $("#toggleMultiUpdate").slideUp();
      $(".multiselect-cell").slideDown();
      return true;
    });

    $("#selectAllSelector").on("click", function (e) {
      e.preventDefault();
      window.toggleAllChecked = !window.toggleAllChecked;
      // Only update the current available inputs
      const updatedKind = $(
        "#impoundRecordUpdateForm #impound_record_update_kind"
      ).val();
      $(`.multiselect-cell.canupdate-${updatedKind} input`).prop(
        "checked",
        window.toggleAllChecked
      );
    });
  }

  updateDisabledChecks(updatedKind) {
    $(".multiselect-cell input").prop("disabled", true);
    $(".multiselect-cell").addClass("disabledCell");
    $(`.multiselect-cell.canupdate-${updatedKind} input`).prop(
      "disabled",
      false
    );
    // Remove the checks for disabled inputs
    $(`.multiselect-cell.canupdate-${updatedKind}`).removeClass("disabledCell");
    $(".multiselect-cell.disabledCell input").prop("checked", false);
    // Get the pretty text for the current option
    const updatedKindHumanized = $(
      "#impoundRecordUpdateForm #impound_record_update_kind option:selected"
    ).text();
    // Also, add a title to the ones that can't be updated
    $(`.multiselect-cell.disabledCell`).prop(
      "title",
      `This record can't be updated with '${updatedKindHumanized}'`
    );
  }

  updateKind() {
    const updatedKind = $(
      "#impoundRecordUpdateForm #impound_record_update_kind"
    ).val();

    $("#impoundRecordUpdateForm .collapseKind").each(function (index, field) {
      const $field = $(field);
      if ($field.hasClass(`kind_${updatedKind}`)) {
        $field.addClass("show").addClass("in");
      } else {
        $field.removeClass("show").removeClass("in");
      }
    });

    if (this.indexView) {
      this.updateDisabledChecks(updatedKind);
    }
  }

  initializeEdit() {
    this.updateKind();
    $("#impoundRecordUpdateForm #kindUpdate select").on("change", (event) =>
      this.updateKind()
    );
  }
}
