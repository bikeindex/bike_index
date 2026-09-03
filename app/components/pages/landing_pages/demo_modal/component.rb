# frozen_string_literal: true

module Pages
  module LandingPages
    module DemoModal
      class Component < ApplicationComponent
        def initialize(feedback:, feedback_type:, modal_id:, name_label:, current_user: nil)
          @feedback = feedback
          @current_user = current_user
          @name_label = name_label
          @feedback_type = feedback_type
          @modal_id = modal_id
        end
      end
    end
  end
end
