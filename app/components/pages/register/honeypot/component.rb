# frozen_string_literal: true

module Pages
  module Register
    module Honeypot
      # `additional` coming back is what BikeServices::Register flags the registration on
      class Component < ApplicationComponent
        def call
          tag.div(class: "tw:hidden") do
            safe_join([helpers.label_tag(:additional, "Additional"),
              helpers.text_field_tag(:additional, nil, tabindex: -1, autocomplete: "off")])
          end
        end
      end
    end
  end
end
