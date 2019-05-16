import log from "../utils/log";

function BinxOrgBikes() {
  return {
    init() {
      // I'm concerned about javascript breaking, and the bikes being hidden and unable to be shown.
      // To prevent that, only hide columns after adding this class
      $("#organized_bikes_index").addClass("javascriptFunctioning");
      let self = this;
      this.selectStoredVisibleColumns();
      this.updateVisibleColumns();
      $("#organizedSearchSettings input").on("change", function(e) {
        self.updateVisibleColumns();
      });
      // Make the stolenness toggle work
      $(".organized-bikes-stolenness-toggle").on("click", function(e) {
        e.preventDefault();
        const stolenness = $(".organized-bikes-stolenness-toggle").attr(
          "data-stolenness"
        );
        $("#stolenness").val(stolenness);
        return $("#bikes_search_form").submit();
      });
    },

    selectStoredVisibleColumns() {
      const defaultCells = [
        "created_at_cell",
        "stolen_cell",
        "manufacturer_cell",
        "model_cell",
        "color_cell",
        "owner_email_cell"
      ];
      let visibleCells = localStorage.getItem("organizationBikeColumns");
      // If we have stored cells, select them.
      if (typeof visibleCells === "string") {
        visibleCells = JSON.parse(visibleCells);
      }
      // Unless we have an array with at least one item, make it default
      if (typeof visibleCells !== "array" || visibleCells.length < 1) {
        visibleCells = defaultCells;
      }

      visibleCells.forEach(cellClass =>
        $(`input#${cellClass}`).prop("checked", true)
      );
    },

    updateVisibleColumns() {
      $(".fullscreen-table-wrapper th, .fullscreen-table-wrapper td").addClass(
        "hiddenColumn"
      );
      let enabledCells = $("#organizedSearchSettings input:checked")
        .get()
        .map(cellClass => cellClass.value);
      enabledCells.forEach(cellClass =>
        $(`.${cellClass}`).removeClass("hiddenColumn")
      );
      // Then store the enabled columns
      localStorage.setItem(
        "organizationBikeColumns",
        JSON.stringify(enabledCells)
      );
    }
  };
}

export default BinxOrgBikes;
