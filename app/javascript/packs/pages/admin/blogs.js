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
      $('#new_public_image').fileupload({
        dataType: 'json',
        done: function(e, data) {
          $.each(data.result.files, function(index, file) {
            $('<p/>').text(file.name).appendTo(document.body);
          });
        }
      });
      //       {
      //         dataType: "script",
      //         add(e, data) {
      //           const types = /(\.|\/)(gif|jpe?g|png)$/i;
      //           const file = data.files[0];
      //           $('#public_images').sortable('disable');
      //           if (types.test(file.type) || types.test(file.name)) {
      //             data.context = $(`<div class="upload"><p><em>${file.name}</em></p><div class="progress progress-striped active"><div class="bar" style="width: 0%"></div></div></div>`);
      //             $('#new_public_image').append(data.context);
      //             return data.submit();
      //           } else {
      //             return alert(`${file.name} is not a gif, jpeg, or png image file`);
      //           }
      //         },
      //         progress(e, data) {
      //           if (data.context) {
      //             const progress = parseInt((data.loaded / data.total) * 95, 10); // Multiply by 95, so that it doesn't look done, since progress doesn't work.
      //             return data.context.find('.bar').css('width', progress + '%');
      //           }
      //         },
      //         done(e, data) {
      //           const file = data.files[0];
      //           return $.each(data.files, (index, file) =>
      //             data.context.addClass('finished_upload').html(`\
      // <p><em>${file.name}</em></p>
      // <div class='alert-success'>
      //     Finished uploading
      // </div>\
      // `).fadeOut('slow')
      //           );
      //         }
      //       }
      // );
    }
  };
}


export default BinxAdminBlogs
