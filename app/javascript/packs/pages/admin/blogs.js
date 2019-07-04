import * as FilePond from 'filepond';
import FilePondPluginFileEncode from 'filepond-plugin-file-encode';
import FilePondPluginImageExifOrientation from 'filepond-plugin-image-exif-orientation';
import FilePondPluginImagePreview from 'filepond-plugin-image-preview';
import FilePondPluginFileValidateSize from 'filepond-plugin-file-validate-size';


function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
      this.filePondUpload
    },

    editDate() {
      $("#change_published_date").on("click", e => {
        e.preventDefault();
        $("#blog-date").slideDown()
      })
    },

    filePondUpload() {
      FilePond.create(
        document.querySelector('#pond')
      );


      FilePond.setOptions({
        server: {
          url: "/public_images/create",
          process: {
            url: './process',
            method: 'POST',
            withCredentials: false,
            headers: {},
            timeout: 7000,
            onload: null,
            onerror: null,
            ondata: null
          }
        }
      });
    }
  };
}


export default BinxAdminBlogs
