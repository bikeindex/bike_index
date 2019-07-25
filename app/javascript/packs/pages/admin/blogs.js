import log from "../../utils/log";

function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
      this.setIndexImage();
      this.setIndex();
      this.noPrimaryPhotoToggle();
      this.publicImageDelete();
    },

    editDate() {
      $("#change_published_date").on("click", e => {
        e.preventDefault();
        $("#blog-date").slideDown()
      })
    },

    publicImageDelete() {
      $('ul#public_images').on('click', ".image-delete-button", function(e) {
        e.preventDefault();
        const id = $(".image-delete-button").closest(".row").find("input").val()
        $.ajax({
          url: `/public_images/${id}`,
          type: 'delete'
        });
        this.closest('li').remove()
      })
    },

    noPrimaryPhotoToggle() {
      const noPrimaryPhotoBox = $(".index_image_0")
      noPrimaryPhotoBox.on("change", e => {
        if (noPrimaryPhotoBox.prop("checked")) {
          $(".index-image-select input").prop("checked", false)
        }
      })
    },

    setIndex() {
      const index_image = $('#blog_index_image_id').val()
      return $("li#" + index_image).find($("input")).prop("checked", true)
    },

    setIndexImage(e) {
      $("ul#public_images").on("change", '.index-image-select input', function(e) {
        e.preventDefault();
        if ($('#blog_index_image_id').val != 0) {
          $('#blog_index_image_id').val($(e.target).val());
          $(".index_image_0").prop("checked", false)
        }
      })
    },
  };
}


export default BinxAdminBlogs
