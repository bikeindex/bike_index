import * as FilePond from 'filepond';
import FilePondPluginFileEncode from 'filepond-plugin-file-encode';
import FilePondPluginImageExifOrientation from 'filepond-plugin-image-exif-orientation';
import FilePondPluginImagePreview from 'filepond-plugin-image-preview';
import FilePondPluginFileValidateSize from 'filepond-plugin-file-validate-size';


function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
      this.filePondUpload();
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
          url: './',
          timeout: 7000,
          process: {
            url: './public_images',
            method: 'POST',
            headers: {
              'x-customheader': 'Hello World'
            },
            withCredentials: false,
            onload: this.onLoadFile,
            onerror: (response) => response.data,
            ondata: (formData) => {
              formData.append('Hello', 'World');
              return formData;
            }
          },
          revert: './revert',
          restore: './restore/',
          load: './load/',
          fetch: './fetch/'
        }
      });
    }
  };
}


export default BinxAdminBlogs
