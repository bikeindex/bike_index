Selectize.define('selectable_placeholder', function (options) {
    var self = this;

    options = $.extend({
        placeholder: self.settings.placeholder,
        html: function (data) {
            return (
                '<div class="selectize-dropdown-content placeholder-container">' +
                '<div data-selectable class="option">' + data.placeholder + '</div>' +
                '</div>');
        }
    }, options);

    // override the setup method to add an extra "click" handler
    self.setup = (function () {
        var original = self.setup;
        return function () {
            original.apply(this, arguments);
            self.$placeholder_container = $(options.html(options));
            self.$dropdown.prepend(self.$placeholder_container);
            self.$dropdown.find('.placeholder-container').on('mousedown',  function () {
                //self.setValue('');
                self.clear();
                self.close();
                self.blur();
                return false;
            });
        };
    })();

});

$('#test').selectize({
    create: false,
    dropdownParent: 'body',
    plugins: {
        'selectable_placeholder': {}
    }
});