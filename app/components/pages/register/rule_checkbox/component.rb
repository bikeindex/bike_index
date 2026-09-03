# frozen_string_literal: true

module Pages
  module Register
    module RuleCheckbox
      # A checkbox the register--acknowledgment controller counts before it enables the
      # step's submit. Nameless when there's nothing to submit - the org's preview walks
      # through GET forms, which would otherwise serialize them.
      class Component < ApplicationComponent
        CLASSES = "tw:mt-0.5 tw:h-4 tw:w-4 tw:shrink-0 tw:cursor-pointer"
        DATA = {"register--acknowledgment-target": "checkbox",
                action: "change->register--acknowledgment#update"}.freeze

        def initialize(name: nil, checked: false)
          @name = name
          @checked = checked
        end

        def call
          return tag.input(type: "checkbox", class: CLASSES, data: DATA) if @name.blank?

          check_box_tag(@name, "1", @checked, class: CLASSES, data: DATA)
        end
      end
    end
  end
end
