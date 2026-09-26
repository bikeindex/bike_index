# frozen_string_literal: true

module Pages
  module Stolen
    module Index
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Stolen::Index::Component.new(recoveries_count: 18_263,
            recoveries_value: 38_412_345, organizations_count: 1_000,
            recovery_displays: RecoveryDisplay.with_photo, feedback: Feedback.new(email: User.first&.email), current_user: User.first))
        end
      end
    end
  end
end
