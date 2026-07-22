# frozen_string_literal: true

module Registrations
  module Show
    module Share
      # A share button that uses the Web Share API, falling back to copying the URL
      class Component < ApplicationComponent
        def initialize(text:, url:)
          @text = text
          @url = url
        end

        def call
          content_tag(:button, type: "button",
            class: "tw:w-full #{UI::Button::Component.build_classes(color: :outline, size: :md, html_class: "tw:justify-center tw:py-2.5!")}",
            data: {controller: "registrations--show--share",
                   "registrations--show--share-url-value": @url,
                   action: "registrations--show--share#share"}) do
            content_tag(:span, @text, data: {"registrations--show--share-target": "label"})
          end
        end
      end
    end
  end
end
