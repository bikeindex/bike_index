import log from "../../utils/log";

// required for uppy file upload
import "es6-promise/auto";
import "whatwg-fetch";
require("@uppy/core/dist/style.css");
require("@uppy/dashboard/dist/style.css");
window.Uppy = require("@uppy/core");
window.XHRUpload = require("@uppy/xhr-upload");
window.Dashboard = require("@uppy/dashboard");
window.DragDrop = require("@uppy/drag-drop");
window.Tus = require("@uppy/tus");
window.ProgressBar = require("@uppy/progress-bar");
window.FileInput = require("@uppy/file-input");
window.Form = require("@uppy/form");

function BinxAdminImageUploader() {
  return {
    init() {
      this.uppyFileUpload();
    },

    uppyFileUpload() {
      const uppyOne = new Uppy({
        debug: true,
        autoProceed: true,
      });
      uppyOne
        .use(FileInput, {
          target: ".UppyForm",
          inputName: "public_image[image]",
        })
        .use(XHRUpload, {
          endpoint: "/public_images",
          formData: true,
          fieldName: "file",
          method: "post",
        })
        .use(Dashboard, {
          target: ".UppyDragDrop-One",
          inline: true,
        })
        .use(ProgressBar, {
          target: ".UppyDragDrop-One-Progress",
          hideAfterFinish: false,
        });
      uppyOne.use(Form, {
        target: "#new_public_image",
        getMetaFromForm: true,
        addResultToForm: true,
        multipleResults: false,
        submitOnSuccess: false,
        triggerUploadOnSubmit: false,
      });
      uppy.on("upload-success", (file, response) => {
        $("ul#public_images").append(
          this.publicImageTemplate(response.body.public_image)
        );
      });
    },

    publicImageTemplate(image) {
      const alt = image.name;
      const src = image.image.url;
      const id = image.id;
      return `<li class="admin-public-image collapse show mt-1 col-xl-4 col-sm-6" id="image-${id}" data-imageid="${id}">
          <div class='card bg-light'>
            <div class='card-body'>
              <div class='row'>
                <div class='col-3'>
                  <div class='img-box'>
                    <img src='${src}' alt='${alt}'/>
                  </div>
                  <p class="image-filename">${alt}</p>
                </div>
                <div class='col-9'>
                  <textarea class='form-control'> &lt;img class='post-image' src='${src}' alt='ENTER YOUR TEXT HERE'&gt; </textarea>
                </div>
              </div>
              <div class='row'>
                <div class='col-6'>
                  <a href='#' class="image-delete-button"> Delete</a>
                </div>
                <div class='col-6 text-right'>
                  <label class="index-image-select form-check-inline">
                    <input class="index_image_${id}" name="index_image_id" type="radio" value="${id}"></input>
                    <em class="ml-1">primary image</em>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
      </li>`;
    },
  };
}

export default BinxAdminImageUploader;
