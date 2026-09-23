# frozen_string_literal: true

module Pages
  module Stolen
    module Index
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Stolen::Index::Component.new(recoveries_count: 18_263,
            recoveries_value: 38_412_345, organizations_count: 1_000,
            recovery_displays: RecoveryDisplay.all))
        end
      end
    end
  end
end
