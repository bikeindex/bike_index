// import "blueimp-file-upload/js/vendor/jquery.ui.widget.js";
// import "blueimp-file-upload/js/jquery.iframe-transport.js";
// import "blueimp-file-upload/js/jquery.fileupload.js";
// import "blueimp-file-upload/js/jquery.fileupload-image.js";
window.$ = window.jQuery = jQuery;
require('script-loader!blueimp-file-upload/js/vendor/jquery.ui.widget.js');
require('script-loader!blueimp-tmpl/js/tmpl.js');
require('script-loader!blueimp-load-image/js/load-image.all.min.js');
require('script-loader!blueimp-canvas-to-blob/js/canvas-to-blob.js');
require('script-loader!blueimp-file-upload/js/jquery.iframe-transport.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-process.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-image.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-audio.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-video.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-validate.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-ui.js');

function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
      this.publicImageFileUpload()
    },

    editDate() {
      $("#change_published_date").on("click", e => {
        e.preventDefault();
        $("#blog-date").slideDown()
      })
    },
   publicImageFileUpload() {

    }
  };
 }


export default BinxAdminBlogs
