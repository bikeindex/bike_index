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
        const $image_btn = $("#use_image_for_display");
        if ($image_btn.hasClass("using_bikes")) {
          $("#recovery-photo-upload-input").slideDown();
          $("#recovery_display_remote_image_url").val("");
          $image_btn.text("Use first image");
        } else {
          $("#recovery-photo-upload-input").slideUp();
          $("#recovery_display_remote_image_url").val(
            $image_btn.attr("data-url")
          );
          $image_btn.text("nvrmind");
        }
        return $image_btn.toggleClass("using_bikes");
      });
    },

    setCharacterCount() {
      $("#characterTotal").text($("#characterCounter").val().length + "/300");
    },

    characterCounter() {
      let self = this;
      $("#characterCounter").on("keyup", function(e) {
        e.preventDefault();
        self.setCharacterCount();
      });
    }
  }
}

export default BinxAdminRecoveryDisplayForm;
