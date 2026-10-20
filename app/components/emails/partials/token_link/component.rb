# frozen_string_literal: true

module Emails
  module Partials
    module TokenLink
      # Postmark's click tracking would rewrite the link through its own redirect - leaking the token
      # to the tracker, and flagging the email to filters like Defender and Proofpoint
      class Component < ApplicationComponent
        def initialize(href:, text: nil, html_class: "binx-button")
          @href = href
          @text = text
          @html_class = html_class
        end

        def call
          link_to(@text || content, @href, class: @html_class, "data-pm-no-track": true)
        end
      end
    end
  end
end
