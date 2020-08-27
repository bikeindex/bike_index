const EnableEscapeForModals = () => {
  $(".modal").on("show.bs.modal", () => {
    $(window).on("keyup", function (e) {
      if (e.keyCode === 27) {
        // Hide last modal - if there are overlapping modals, the last is the visible one
        $(".modal.show").last().modal("hide"); // Escape key
      }
      return true;
    });
  });
  // Remove keyup trigger, clean up after yourself
  $(".modal").on("hide.bs.modal", () => {
    // Only remove it if there are no more active modals
    if ($(".modal.show").length === 0) {
      $(window).off("keyup");
    }
  });
};

export default EnableEscapeForModals;
