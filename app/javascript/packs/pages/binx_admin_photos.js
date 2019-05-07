function BinxAdminPhotos() {
  return {
    init() {
      this.initializeEventListeners();
      this.initializeSortablePhotos();
      this.initializeImageUploads();
    },

    initializeEventListeners() {
      $("#public_images").on("change", ".is_private_check", e => {
        return this.updateImagePrivateness(e);
      });
      return $(".edit-form-well-submit-wrapper .btn").click(function(e) {
        e.preventDefault();
        return location.reload(true);
      });
    },

    initializeImageUploads() {
      const { initializeSortablePhotos } = this;
      const finished_upload_template = $(
        "#image-upload-finished-template"
      ).html();
      Mustache.parse(finished_upload_template);
      return $("#new_public_image").fileupload({
        dataType: "script",
        add(e, data) {
          const types = /(\.|\/)(gif|jpe?g|png|tiff?)$/i;
          const file = data.files[0];
          $("#public_images").sortable("disable");
          if (types.test(file.type) || types.test(file.name)) {
            data.context = $(
              `<div class='upload'><p><em>${
                file.name
              }</em></p><progress class='progress progress-info'>0%</progress></div>`
            );
            $("#new_public_image").append(data.context);
            return data.submit();
          } else {
            return window.BikeIndexAlerts.add(
              "error",
              `${file.name} is not a gif, jpeg, or png image file`
            );
          }
        },
        progress(e, data) {
          if (data.context) {
            const progress = parseInt((data.loaded / data.total) * 95, 10); // Multiply by 95, so that it doesn't look done, since progress doesn't work.
            return data.context.find(".progress").text(progress + "%");
          }
        },
        done(e, data) {
          initializeSortablePhotos();
          const file = data.files[0];
          return $.each(data.files, (index, file) =>
            data.context
              .addClass("finished_upload")
              .html(Mustache.render(finished_upload_template, file))
              .fadeOut()
          );
        }
      });
    },

    initializeSortablePhotos() {
      const $sortable_container = $("#public_images");
      $sortable_container.sortable("destroy"); // In case we're reinitializing it
      const { pushImageOrder } = this;
      return $sortable_container.sortable({
        onDrop($item, container, _super) {
          // Push image order
          pushImageOrder($sortable_container);
          // Run the things we're expected to run
          return _super($item, container);
        }
      });
    },

    pushImageOrder($sortable_container) {
      const url_target = $sortable_container.data("orderurl");
      const sortable_list_items = $sortable_container.children("li");
      // This is a list comprehension for the list of all the sortable items, to make an array
      const array_of_photo_ids = Array.from(sortable_list_items).map(
        list_item => $(list_item).prop("id")
      );
      const new_item_order = { list_of_photos: array_of_photo_ids };
      // list_of_items is an array containing the ordered list of image_ids
      // Then we post the result of the list comprehension to the url to update
      return $.post(url_target, new_item_order);
    },

    updateImagePrivateness(e) {
      const $target = $(e.target);
      const is_private = $target.prop("checked");
      const id = $target.parents(".edit-photo-display-list-item").prop("id");
      const url_target = `${$("#public_images").data(
        "imagesurl"
      )}/${id}/is_private`;
      return $.post(url_target, { is_private });
    }
  };
}
export default BinxAdminPhotos;
