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
      const uppy = new Uppy({
        debug: true,
        autoProceed: true
      })
      uppy.use(FileInput, {
        target: '.UppyForm',
        replaceTargetContent: true
      })
      uppy.use(XHRUpload, {
        endpoint: '/public_images',
        method: "POST",
        formData: true,
        fieldName: 'files[]'
      })
    }
  };
}


export default BinxAdminBlogs
