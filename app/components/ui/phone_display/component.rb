# frozen_string_literal: true

module UI
  module PhoneDisplay
    class Component < ApplicationComponent
      LINK_CLASS = "twlink tw:font-mono"
      TEXT_CLASS = "tw:font-mono"

      def initialize(phone: nil, skip_link: false, html_class: nil, **html_options)
        # The component builds its own class, so a passed one is dropped rather than merged
        raise ArgumentError, "class is not supported, you must use the keyword arg html_class" if html_options.key?(:class)

        @phone = Phonifyer.display(phone)
        @skip_link = skip_link
        @html_class = html_class
        @html_options = html_options
      end

      def render?
        @phone.present?
      end

      # html_options lead, so the component's own attributes can't be overwritten
      def call
        return content_tag(:span, @phone, **@html_options, class: @html_class || TEXT_CLASS) if @skip_link

        # `;` makes the dialer pause before sending the extension
        link_to(@phone, "tel:#{@phone.tr("x", ";")}", **@html_options, class: @html_class || LINK_CLASS)
      end
    end
  end
end
