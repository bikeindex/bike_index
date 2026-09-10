# frozen_string_literal: true

module UI
  module Forms
    module FileUploadMulti
      # A picker that stores each file as it's chosen, rather than a field a surrounding form
      # posts: every pick goes to `url` in a request of its own, carrying `params`, and the
      # endpoint answers {html:} with the markup for what it stored (or {error:} with why it
      # wouldn't). Already-stored items are the component's content, and new ones join them.
      class Component < ApplicationComponent
        # mb-0 cancels legacy bootstrap's `label` margin, which items-center would
        # otherwise center along with the text next to it.
        LABEL_CLASSES = "tw:mb-0 tw:whitespace-nowrap tw:peer-focus-visible:ring-3 tw:peer-focus-visible:ring-blue-500/40"

        def initialize(url:, file_param:, params: {}, accept: nil, list_html_options: {})
          @url = url
          @file_param = file_param
          @params = params
          @accept = Array(accept).join(",").presence
          @list_html_options = list_html_options
          # Random, so two uploaders on a page don't hand both labels the same input
          @input_id = "file_upload_multi_#{SecureRandom.hex(4)}"

          # Style the label as a UI::Button; the focus ring is driven by the peer (sr-only) input.
          @label_classes = UI::Button::Component.build_classes(color: :secondary, size: :md, html_class: LABEL_CLASSES)
        end

        private

        # The button's gap-1.5 spaces these; the icon is decorative, the text names it.
        def label_content
          safe_join([
            helpers.inline_svg_tag("icons/upload.svg", class: "tw:h-4 tw:w-4", aria_hidden: true),
            translation(".upload")
          ])
        end
      end
    end
  end
end
