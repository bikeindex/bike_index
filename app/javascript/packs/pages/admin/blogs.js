import log from "../../utils/log";
import 'es6-promise/auto'
import 'whatwg-fetch'
require('@uppy/core/dist/style.css')
require('@uppy/dashboard/dist/style.css')

function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
      this.uppyFileUpload();
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
    }
  };
}


export default BinxAdminBlogs
