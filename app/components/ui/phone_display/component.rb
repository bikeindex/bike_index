# frozen_string_literal: true

module UI
  module PhoneDisplay
    class Component < ApplicationComponent
      LINK_CLASS = "twlink tw:font-mono"
      TEXT_CLASS = "tw:font-mono"

      def initialize(phone: nil, skip_link: false)
        @phone = Phonifyer.display(phone)
        @skip_link = skip_link
      end

      def render?
        @phone.present?
      end

      def call
        return content_tag(:span, @phone, class: TEXT_CLASS) if @skip_link

        # `;` makes the dialer pause before sending the extension
        link_to(@phone, "tel:#{@phone.tr("x", ";")}", class: LINK_CLASS)
      end
    end
  end
end
