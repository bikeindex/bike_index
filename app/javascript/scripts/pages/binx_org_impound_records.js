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
    } else {
      this.initializeShow();
    }
  }

  initializeIndex() {
    // Call the existing coffeescript class that manages the bike searchbar
    new BikeIndex.BikeSearchBar();
  }

  initializeShow() {
    $("#impoundRecordUpdateForm #impound_record_update_kind").on(
      "change",
      (event) => {
        const updatedKind = $(
          "#impoundRecordUpdateForm #impound_record_update_kind"
        ).val();
        $("#impoundRecordUpdateForm .collapseKind").each(function(
          index,
          field
        ) {
          const $field = $(field);
          if ($field.hasClass(`kind_${updatedKind}`)) {
            $field.addClass("show").addClass("in");
          } else {
            $field.removeClass("show").removeClass("in");
          }
        });
      }
    );
  }
}
