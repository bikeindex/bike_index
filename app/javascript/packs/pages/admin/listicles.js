import log from "../../utils/log";



function BinxAdminListicles() {
  return {
    init() {
      this.listicleEdit();
      this.editDate();
    },

    editDate() {
      $("#change_published_date").on("click", e => {
        e.preventDefault();
        $("#blog-date").slideDown()
      })
    },

    listicleEdit() {
      for (let image of Array.from($('#listicle_image .list-image'))) {
        const block_number = $(image).attr('data-order');
        $(`.page_number_${block_number}`).prepend($(image));
      }

      const total = $('.listicle-block fieldset').length;
      $('.listicle-block .current-count').text(`/${total}`);

      $('form').on('click', '.add_fields', function(event) {
        event.preventDefault();
        const time = new Date().getTime();
        const regexp = new RegExp($(this).data('id'), 'g');
        $(this).before($(this).data('fields').replace(regexp, time));
        let last_item = 0;
        const iterable = $('.list-order input');
        for (let i = 0; i < iterable.length; i++) {
          const lo = iterable[i];
          const list_order = parseInt($(lo).val(), 10);
          if (list_order > last_item) { last_item = list_order; }
        }

        return $('.list-order input').last().val(last_item + 1);
      });

      return $('form').on('click', '.remove_fields', function(event) {
        $(this).prev('.remove-listicle-block').val('1');
        $(this).closest('fieldset').slideUp();
        return event.preventDefault();
      });
    }
  };
}


export default BinxAdminListicles
