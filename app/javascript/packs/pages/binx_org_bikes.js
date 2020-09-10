import log from "../utils/log";

function BinxAppOrgBikes() {
  return {
    init() {
      // If there aren't search settings on the page, don't do anything
      if ($("#organizedSearchSettings").length) {
        this.initSearchColumns();
      }
    },

    initSearchColumns() {
      // I'm concerned about javascript breaking, and the bikes being hidden and unable to be shown.
      // To prevent that, only hide columns after adding this class
      $("#organized_bikes_index").addClass("javascriptFunctioning");
      let self = this;
      this.selectStoredVisibleColumns();
      this.updateVisibleColumns();
      $("#organizedSearchSettings input").on("change", function (e) {
        self.updateVisibleColumns();
      });
      // Make the stolenness toggle work
      $(".organized-bikes-stolenness-toggle").on("click", function (e) {
        e.preventDefault();
        const stolenness = $(".organized-bikes-stolenness-toggle").attr(
          "data-stolenness"
        );
        $("#stolenness").val(stolenness);
        return $("#bikes_search_form").submit();
      });
      // When the avery cell is checked, add it to the params.
      $("#avery_cell").on("change", function (e) {
        let urlParams = new URLSearchParams(window.location.search);
        urlParams.delete("avery_export");
        urlParams.delete("search_open");
        urlParams.append("avery_export", $("#avery_cell").prop("checked"));
        urlParams.append("search_open", true);
        window.location = `${location.pathname}?${urlParams.toString()}`;
      });
      $("#per_page_select").on("change", function (e) {
        let urlParams = new URLSearchParams(window.location.search);
        urlParams.delete("per_page");
        urlParams.append("per_page", $("#per_page_select").val());
        window.location = `${location.pathname}?${urlParams.toString()}`;
      });
    },

    selectStoredVisibleColumns() {
      const defaultCells = JSON.parse(
        $("#organizedSearchSettings").attr("data-defaultcols")
      );
      let visibleCells = localStorage.getItem("organizationBikeColumns");
      // If we have stored cells, select them.
      if (typeof visibleCells === "string") {
        visibleCells = JSON.parse(visibleCells);
      }
      // Unless we have an array with at least one item, make it default
      if (typeof visibleCells !== "array" || visibleCells.length < 1) {
        visibleCells = defaultCells;
      }

      visibleCells.forEach((cellClass) =>
        $(`input#${cellClass}`).prop("checked", true)
      );
    },

    updateVisibleColumns() {
      $(".full-screen-table th, .full-screen-table td").addClass(
        "hiddenColumn"
      );
      let enabledCells = $("#organizedSearchSettings input:checked")
        .get()
        .map((cellClass) => cellClass.value);
      enabledCells.forEach((cellClass) =>
        $(`.${cellClass}`).removeClass("hiddenColumn")
      );
      // Then store the enabled columns
      localStorage.setItem(
        "organizationBikeColumns",
        JSON.stringify(enabledCells)
      );
    },
  };
}

export default BinxAppOrgBikes;
