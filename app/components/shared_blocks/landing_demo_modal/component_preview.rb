# frozen_string_literal: true

module SharedBlocks
  module LandingDemoModal
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(SharedBlocks::LandingDemoModal::Component.new(
          feedback: Feedback.new,
          name_label: "School",
          feedback_type: "lead_for_school",
          modal_id: "schools-demo-modal"
        ))
      end
    end
  end
end
