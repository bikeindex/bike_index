import log from "../../utils/log";

function BinxAdminRecoveryDisplayForm() {
  return {
    init() {
      this.setCharacterCount();
      this.characterCounter();

      // Toggle image initially if we should
      if (
        $("#recovery-display-form").attr("data-toggleimageinitially") == "true"
      ) {
        this.toggleBikeImageForDisplay();
      }
      let self = this;
      $("#use_image_for_display").on("click", e => {
        e.preventDefault();
        self.toggleBikeImageForDisplay();
      });
    },

    toggleBikeImageForDisplay() {
      if ($("#recovery-bike-image-text").hasClass("bike-image-added")) {
        $("#recovery-photo-upload-input").collapse("show");
        $("#recovery_display_remote_image_url").val("");
        $("#recovery-bike-image-text").removeClass("bike-image-added");
      } else {
        $("#recovery-photo-upload-input").collapse("hide");
        $("#recovery_display_remote_image_url").val(
          $("#use_image_for_display").attr("data-url")
        );
        $("#recovery-bike-image-text").addClass("bike-image-added");
      }
    },

    setCharacterCount() {
      $("#characterTotal").text(`${$("#characterCounter").val().length}/300`);
    },

    characterCounter() {
      $("#characterCounter").on("keyup", e => {
        e.preventDefault();
        this.setCharacterCount();
      });
    }
  };
}

export default BinxAdminRecoveryDisplayForm;
