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



function BinxCustomLayouts() {
  return {
    init() {
      this.uppyFileUpload();
      log.debug("Hey")
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
        $("ul#public_images").append(this.publicImageTemplate(response.body.public_image))
      })
    },

    publicImageTemplate(image) {
      const alt = image.name
      const src = image.image.url
      return `<li>
          <div class='card bg-light admin-public-image'>
            <div class='card-body'>
              <div class='row'>
                <div class='col-md-2 col-sm-6 mt-auto'>
                  <p>
                    ${alt}
                  </p>
              </div>
              <div class='col-md-8 col-sm-6 mt-auto'>
               <textarea class='form-control'> &lt;img class='post-image' src='${src}' alt='ENTER YOUR TEXT HERE'&gt; </textarea>
              </div>
              <div class='col-md-2 col-sm-12'>
                <div class='img-box'>
                  <img src='${src}' alt='${alt}'/>
                </div>
              </div>
            </div>
            <hr/>
            <div class='row mt-2'>
              <div class='col-md-8'>
                <span> Copy the above text and paste it where you'd like it to appear in the post </span>
              </div>
            </div>
          </div>
        </div>
      </li>`
    }
  };
}


export default BinxCustomLayouts
