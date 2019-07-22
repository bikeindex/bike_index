import log from "../../utils/log";

// required for uppy file upload
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
      this.setIndex();
      this.noPrimaryPhotoToggle();
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
      uppy.on('upload-success', (file, response) => {
        this.appendPublicImage(response.body.public_image);
      })
    },

    appendPublicImage(image) {
      const partial = "<%img src="+ image.image_url +">"

      const list = $("ul#public_images")
      list.append(partial)
    },

    noPrimaryPhotoToggle() {
      const $noPrimaryBox = $(".index_image_0")
      $noPrimaryBox.on("change", e => {
        if ($noPrimaryBox.prop("checked")) {
          $(".index-image-select input").prop("checked", false)
        }
      })
    },

    setIndex() {
      const index_image = $('#blog_index_image_id').val()
      return $("li#" + index_image).find($("input")).prop("checked", true)
    },

    setIndexImage(e) {
      $('.index-image-select input').on("change", e => {
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
