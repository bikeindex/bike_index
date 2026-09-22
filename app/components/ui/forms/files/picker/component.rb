# frozen_string_literal: true

module UI
  module Forms
    module Files
      module Picker
        # The controls UI::Forms::Files::Upload and UploadMultiple share: an Upload button (and a camera one,
        # for images on a touch device), the name of what was picked, and a frame that takes a
        # dropped file. What's already attached renders above them, and a status below.
        class Component < ApplicationComponent
          # mb-0 cancels legacy bootstrap's `label` margin, which items-center would
          # otherwise center along with the button next to it. The ring restates
          # UI::Button's COLORS[:secondary] focus color under the peer variant.
          LABEL_CLASSES = "tw:mb-0 tw:whitespace-nowrap tw:peer-focus-visible:ring-3 tw:peer-focus-visible:ring-purple-500/40"

          renders_one :attached
          renders_one :status

          # Without a form_builder the input is a bare one, and html_options needs an id for its label
          def initialize(form_builder: nil, attribute: nil, html_options: {}, accept: nil, camera: nil)
            @form_builder = form_builder
            @attribute = attribute
            accept_list = Array(accept).flat_map { it.to_s.split(",") }.filter_map { it.strip.presence }
            # `capture` hands back a photo, so the camera is only offered when nothing
            # but images are accepted -- never on a CSV or PDF field.
            @camera = camera.nil? ? accept_list.any? && accept_list.all? { image?(it) } : camera
            @placeholder = translation(".no_file_chosen")
            @html_options = {
              class: "tw:peer tw:sr-only",
              accept: accept_list.join(",").presence,
              data: {"ui--forms--files--picker-target": "input", action: "ui--forms--files--picker#display"}
            }.deep_merge(html_options)
            @input_id = @html_options[:id] || form_builder&.field_id(attribute)

            # Style the label as a UI::Button; the focus ring is driven by the peer (sr-only) input.
            @label_classes = UI::Button::Component.build_classes(color: :secondary, size: :md, html_class: LABEL_CLASSES)
          end

          private

          # A form field goes through its builder, which is what makes the form multipart
          def file_input
            return tag.input(type: "file", **@html_options) unless @form_builder

            @form_builder.file_field(@attribute, @html_options)
          end

          # The button's gap-1.5 spaces these; the icon is decorative, the text names it.
          def label_content
            safe_join([
              helpers.inline_svg_tag("icons/upload.svg", class: "tw:h-4 tw:w-4", aria_hidden: true),
              translation(".upload")
            ])
          end

          def image?(accept_entry)
            accept_entry.start_with?("image/") || ApplicationUploader.permitted_extensions.include?(accept_entry.downcase)
          end
        end
      end
    end
  end
end
