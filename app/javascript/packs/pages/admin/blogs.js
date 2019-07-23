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
      this.publicImageDelete();
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
        this.appendPublicImage(response.body.public_image)
      })
    },

    publicImageDelete() {
      $('ul#public_images').on('click', ".image-delete-button", function(e) {
        e.preventDefault();
        const id = $(".image-delete-button").closest(".row").find("input").val()
        console.log(id)
        let url_string = `/public_images/${id}`;
        $.ajax({
          url: url_string,
          type: 'delete'
        });
        this.closest('li').remove()
      })
    },

    appendPublicImage(image) {
      const alt = image.name
      const src = image.image.url
      const id = image.id
      const publicImage =

        `<li>
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
              <div class='col-md-2'>
                <a href='#' class="image-delete-button"> Delete</a>
              </div>
              <div class='col-md-8'>
                <span> Copy the above text and paste it where you'd like it to appear in the post </span>
              </div>
              <div class='col-md-2'>
                <div class="index-image-select">
                  <input class="index_image_${id}" name="index_image_id" type="radio" value="${id}"></input>
                </div>
              </div>
            </div>
          </div>
        </div>
      </li>`

      const list = $("ul#public_images")
      list.append(publicImage)
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
      $("ul#public_images").on("change", '.index-image-select input', function(e){
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
