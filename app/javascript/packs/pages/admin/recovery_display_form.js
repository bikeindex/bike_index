import log from "../../utils/log";

function BinxAdminRecoveryDisplayForm() {
  return {
    init() {
      this.useBikeImageForDisplay();
      this.setCharacterCount();
      this.characterCounter();
    },

    useBikeImageForDisplay() {
      $("#use_image_for_display").on("click", e => {
        e.preventDefault();
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
      });
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
