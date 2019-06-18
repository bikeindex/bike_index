function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
    },

    editDate() {
      $("#change_published_date").on("click", e => {
        e.preventDefault();
        $("#blog-date").slideDown()
      })
    }

  }
}

export default BinxAdminBlogs
