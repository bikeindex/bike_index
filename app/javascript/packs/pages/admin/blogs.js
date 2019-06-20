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
