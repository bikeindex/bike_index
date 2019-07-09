import log from "../../utils/log";

function BinxAdminBlogs() {
  return {
    init() {
      this.editDate()
      this.uppyFileUpload();
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
        .use(DragDrop, {
          target: '.UppyDragDrop-One'
        })
        .use(Tus, {
          endpoint: 'https://master.tus.io/files/'
        })
        // .use(ProgressBar, {
        //   target: '.UppyDragDrop-One-Progress',
        //   hideAfterFinish: false
        // })

      // const uppyTwo = new Uppy({
      //   debug: true,
      //   autoProceed: false
      // })
      // uppyTwo
      //   .use(DragDrop, {
      //     target: '#UppyDragDrop-Two'
      //   })
      //   .use(Tus, {
      //     endpoint: 'https://master.tus.io/files/'
      //   })
      //   .use(ProgressBar, {
      //     target: '.UppyDragDrop-Two-Progress',
      //     hideAfterFinish: false
      //   })

      // let uploadBtn = document.querySelector('.UppyDragDrop-Two-Upload')
      // uploadBtn.addEventListener('click', function() {
      //   uppyTwo.upload()
      // })
    }
  };
}


export default BinxAdminBlogs
