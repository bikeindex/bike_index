# frozen_string_literal: true

module Pages
  module LandingPages
    module DemoModal
      class Component < ApplicationComponent
        # Needs a digit, and turns away an @ - an email in the wrong field. Anything else
        # goes, since extensions and vanity numbers are written every which way
        PHONE_PATTERN = "[^@]*[0-9][^@]*"

        # return_to: where a sent request lands. The form carries it because once a failed
        # submit has re-rendered the page, the referer is /feedbacks
        # role_options: [label, value] pairs, for a page that asks the visitor's role
        def initialize(feedback:, feedback_type:, modal_id:, name_label:, return_to:, title:, submit_text:,
          submit_color: :yellow, role_options: nil, current_user: nil)
          @feedback = feedback
          @feedback_type = feedback_type
          @modal_id = modal_id
          @name_label = name_label
          @return_to = return_to
          @title = title
          @submit_text = submit_text
          @submit_color = submit_color
          @role_options = role_options
          @current_user = current_user
        end

        private

        def form_controllers = ["form-persist strip-inputs", ("autofocus" if @feedback.errors.any?)].compact.join(" ")
      end
    end
  end
end
