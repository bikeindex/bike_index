import log from "../../utils/log";

function BinxAdminBikesEdit() {
  return {
    init() {
      window.originalSerialNumber = $("#bike_serial_number").val();
      $(".serial-check input").on("change", e => {
        this.updateSerialDisplay();
      });
      this.bikesEditRecoverySlide();
    },

    updateSerialDisplay() {
      if ($(".serial-check input:checked").length) {
        if ($(".serial-check-made-without input:checked").length) {
          log.debug("in made without");
          $(".serial-check-unknown input").prop("checked", false);
          $("#bike_serial_number").val("made_without_serial");
        } else {
          $("#bike_serial_number").val("unknown");
        }
        $("#bike_serial_number").addClass("fake-disabled");
      } else {
        $(".serial-check").collapse("show");
        $("#bike_serial_number").val(window.originalSerialNumber);
        $("#bike_serial_number").removeClass("fake-disabled");
      }
    },

    bikesEditRecoverySlide() {
      const $this = $("#bike_stolen");
      $this.on("change", e => {
        e.preventDefault();
        if ($this.prop("checked")) {
          $("#admin-recovery-fields").slideUp();
        } else {
          $("#admin-recovery-fields").slideDown();
        }
      });
    }
  };
}
export default BinxAdminBikesEdit;
