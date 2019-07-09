import log from "../../utils/log";


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
  };
}


export default BinxAdminBlogs
