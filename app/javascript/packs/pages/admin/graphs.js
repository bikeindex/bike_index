function BinxAdminGraphs() {
  return {
    init() {
      this.changeGraphCalendarBox()
      this.setCustomGraphStartAndSlide()
    },
    changeGraphCalendarBox() {
      $("select#graph_date_option").on("change", e => {
        e.preventDefault();
        this.setCustomGraphStartAndSlide();
      });
    },

    startGraphTimeSet() {
      const graphSelected = $("select#graph_date_option")[0].value.split(",");
      const amount = Number(graphSelected[0]);
      const unit = graphSelected[1];
      $("#start_at").val(
        moment()
          .subtract(amount, unit)
          .format("YYYY-MM-DDTHH:mm")
      );
    },

    setCustomGraphStartAndSlide() {
      if ($("select#graph_date_option")[0].value === "custom") {
        $(".calendar-box").slideDown();
      } else {
        $(".calendar-box").slideUp();
        this.startGraphTimeSet();
      }
    },
  }
}
export default BinxAdminGraphs;
