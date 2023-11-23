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
      $("body").addClass("javascriptFunctioning");
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
      // When the avery cell is checked, add it to the params and make the search settings open
      $("#avery_cell").on("change", function (e) {
        let urlParams = new URLSearchParams(window.location.search);
        urlParams.delete("search_avery_export");
        urlParams.delete("search_open");
        const averySearch = $("#avery_cell").prop("checked");
        urlParams.append("search_avery_export", averySearch);
        urlParams.append("search_open", averySearch);
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
      let visibleCells = localStorage.getItem("orgBikeColumns");
      // If we have stored cells, select them.
      if (typeof visibleCells === "string") {
        visibleCells = visibleCells.split(",").filter(Boolean); // removes empty elements from the array
      }
      // Unless we have an array with at least one item, make it default
      if (!Array.isArray(visibleCells) || visibleCells.length < 1) {
        log.debug("Overriding visibleCells with defaultCells");
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
      localStorage.setItem("orgBikeColumns", enabledCells.join(","));
    },
  };
}

export default BinxAppOrgBikes;
