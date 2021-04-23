import log from "./log";

export class BikeIndexUtilities {
  enableEscapeForModals() {
    window.escapeForModalsEnabled = false;
    $(".modal").on("show.bs.modal", () => {
      if (window.escapeForModalsEnabled) {
        return true;
      }
      window.escapeForModalsEnabled = true;
      $(window).on("keyup", function (e) {
        if (e.keyCode === 27) {
          // Hide last modal - if there are overlapping modals, the last is the visible one
          $(".modal.show").last().modal("hide"); // Escape key
          // If there have been multiple
          if ($(".modal.show").length === 0) {
            $(window).off("keyup");
            window.escapeForModalsEnabled = false;
          }
        }
        return true;
      });
    });
    // Remove keyup trigger, clean up after yourself
    $(".modal").on("hide.bs.modal", () => {
      // Only remove it if there are no more active modals
      if ($(".modal.show").length === 0) {
        $(window).off("keyup");
        window.escapeForModalsEnabled = false;
      }
    });
  }

  enableFilenameForUploads() {
    $("input.custom-file-input[type=file]").on("change", function (e) {
      // The issue is that the files list isn't actually an array. So we can't map it
      let files = [];
      let i = 0;
      while (i < e.target.files.length) {
        files.push(e.target.files[i].name);
        i++;
      }
      $(this).parent().find(".custom-file-label").text(files.join(", "));
    });
  }

  enableFullscreenOverflow() {
    const pageWidth = $(window).width();
    $(".full-screen-table table").each(function (index) {
      const $this = $(this);
      if ($this.outerWidth() > pageWidth) {
        $this
          .parents(".full-screen-table")
          .addClass("full-screen-table-overflown");
      }
    });
  }

  init() {
    this.enableEscapeForModals();
    this.enableFilenameForUploads();
    this.enableFullscreenOverflow();
  }
}
