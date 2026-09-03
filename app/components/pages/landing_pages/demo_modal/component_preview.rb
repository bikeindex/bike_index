# frozen_string_literal: true

module Pages
  module LandingPages
    module DemoModal
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::DemoModal::Component.new(
            feedback: Feedback.new,
            name_label: "School",
            feedback_type: "lead_for_school",
            modal_id: "schools-demo-modal"
          ))
        end
      end
    end
  end
end
