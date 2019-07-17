import log from "../../utils/log";

// required for uppy file upload
import 'es6-promise/auto'
import 'whatwg-fetch'
import 'es6-promise/auto'
import 'whatwg-fetch'
require('@uppy/core/dist/style.css')
require('@uppy/dashboard/dist/style.css')
window.Uppy = require('@uppy/core')
window.XHRUpload = require('@uppy/xhr-upload')
window.Dashboard = require('@uppy/dashboard')
window.DragDrop = require('@uppy/drag-drop')
window.Tus = require("@uppy/tus")
window.ProgressBar = require("@uppy/progress-bar")
window.FileInput = require('@uppy/file-input')
window.Form = require("@uppy/form")



function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
      this.uppyFileUpload();
      this.setIndexImage();
      this.listicleEdit();
    },

    editDate() {
      $("#change_published_date").on("click", e => {
        e.preventDefault();
        $("#blog-date").slideDown()
      })
    },

    uppyFileUpload() {
      const uppyOne = new Uppy({
        debug: true,
        autoProceed: true
      })
      uppyOne
        .use(FileInput, {
          target: ".UppyForm",
          inputName: "public_image[image]"
        })
        .use(XHRUpload, {
          endpoint: "/public_images",
          formData: true,
          fieldName: "file",
          method: "post"
        })
        .use(Dashboard, {
          target: '.UppyDragDrop-One',
          inline: true
        })
        .use(ProgressBar, {
          target: '.UppyDragDrop-One-Progress',
          hideAfterFinish: false
        })
      uppyOne.use(Form, {
        target: "#new_public_image",
        getMetaFromForm: true,
        addResultToForm: true,
        multipleResults: false,
        submitOnSuccess: false,
        triggerUploadOnSubmit: false
      })
    },

    setIndexImage(e) {
      return $('#blog_index_image_id').val($(e.target).val());
    },

    listicleEdit() {
      for (let image of Array.from($('#listicle_image .list-image'))) {
        const block_number = $(image).attr('data-order');
        $(`.page_number_${block_number}`).prepend($(image));
      }

      const total = $('.listicle-block fieldset').length;
      $('.listicle-block .current-count').text(`/${total}`);

      $('form').on('click', '.add_fields', function(event) {
        event.preventDefault();
        const time = new Date().getTime();
        const regexp = new RegExp($(this).data('id'), 'g');
        $(this).before($(this).data('fields').replace(regexp, time));
        let last_item = 0;
        const iterable = $('.list-order input');
        for (let i = 0; i < iterable.length; i++) {
          const lo = iterable[i];
          const list_order = parseInt($(lo).val(), 10);
          if (list_order > last_item) { last_item = list_order; }
        }

        return $('.list-order input').last().val(last_item + 1);
      });

      return $('form').on('click', '.remove_fields', function(event) {
        $(this).prev('.remove-listicle-block').val('1');
        $(this).closest('fieldset').slideUp();
        return event.preventDefault();
      });
    }
  };
}


export default BinxAdminBlogs
