import log from "../../utils/log";

function BinxAdminBlogs() {
  return {
    init() {
      this.initializeBlogInfoToggling();
      this.initializePrimaryPhotoFunctionality();
      this.publicImageDelete();
    },

    initializeBlogInfoToggling() {
      $("#infoCheck .form-check-input").on("change", function (e) {
        if ($("#infoCheck .form-check-input").prop("checked")) {
          // It's an info post!
          $(".blogOnlyShow").collapse("hide");
          $(".infoOnlyShow").collapse("show");
        } else {
          $(".blogOnlyShow").collapse("show");
          $(".infoOnlyShow").collapse("hide");
        }
      });
    },

    publicImageDelete() {
      $("ul#public_images").on("click", ".image-delete-button", function (e) {
        e.preventDefault(); // Critical, otherwise the page reloads
        const $li = $(e.target).parents("li");
        const id = $li.attr("data-imageid");
        $.ajax({
          url: `/public_images/${id}`,
          type: "delete",
          success(data, textStatus, jqXHR) {
            log.debug(textStatus);
          },
        });
        $li.collapse("hide");
        return false;
      });
    },

    initializePrimaryPhotoFunctionality() {
      const index_image = $("#blog_index_image_id").val();
      if (index_image.length) {
        $("li#image-" + index_image)
          .find($(".index-image-select input"))
          .prop("checked", true);
      }

      // Update primary image select on change
      $("ul#public_images").on("change", ".index-image-select input", function (
        e
      ) {
        e.preventDefault();
        if ($("#blog_index_image_id").val != 0) {
          $("#blog_index_image_id").val($(e.target).val());
          $(".index_image_0").prop("checked", false);
        }
      });

      // Manage the no primary image photo toggle
      const noPrimaryPhotoBox = $(".index_image_0");
      noPrimaryPhotoBox.on("change", (e) => {
        if (noPrimaryPhotoBox.prop("checked")) {
          $(".index-image-select input").prop("checked", false);
        }
      });
    },
  };
}

export default BinxAdminBlogs;
