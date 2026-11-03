# frozen_string_literal: true

module Pages
  module LandingPages
    module DemoModal
      class Component < ApplicationComponent
        # A digit and no @ (an email in the wrong field) - extensions and vanity numbers
        # are written too many ways to pin down further
        PHONE_PATTERN = "[^@]*[0-9][^@]*"

        # role_options: [label, value] pairs, for a page that asks the visitor's role
        def initialize(feedback:, feedback_type:, modal_id:, name_label:, return_to:, title: nil, submit_text: nil,
          submit_color: :yellow, role_options: nil)
          @feedback = feedback
          @feedback_type = feedback_type
          @modal_id = modal_id
          @name_label = name_label
          @return_to = return_to
          @title = title
          @submit_text = submit_text
          @submit_color = submit_color
          @role_options = role_options
        end

        private

        def title = @title || translation(".title")

        def submit_text = @submit_text || translation(".submit_text")

        def form_controllers = ["form-persist strip-inputs", ("autofocus" if @feedback.errors.any?)].compact.join(" ")

        # A failed send re-renders at POST /feedbacks. The page it came from goes back in the address
        # bar, with the modal open, so a reload returns there
        def sent_from_url
          return unless request.post? && @feedback.errors.any?

          uri = URI.parse(request.referer.to_s)
          uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s).reject { |key, _| key == modal_param } + [[modal_param, "1"]])
          uri.to_s
        rescue URI::InvalidURIError
          nil
        end

        def modal_param = "modal_#{@modal_id}"
      end
    end
  end
end
