import log from "../utils/log";

function BinxAppOrgUserForm() {
  return {
    init() {
      $("#multipleUserSelect").on("click", e => {
        e.preventDefault();
        $("#singleEmailInvite").slideUp();
        // Doing some weird stuff because we can't use collapse here (bootstrap isn't in this pack)
        // And we need display flex, rather than block
        $("#multipleEmailInvite, #multipleEmailInviteField").slideDown();
        $("#multipleEmailInvite").css("display", "flex");
        $("#multipleEmailInvite, #multipleEmailInviteField").removeClass(
          "currently-hidden"
        );
      });
    }
  };
}

export default BinxAppOrgUserForm;
