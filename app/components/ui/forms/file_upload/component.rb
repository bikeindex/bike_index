# frozen_string_literal: true

module UI
  module Forms
    module FileUpload
      class Component < ApplicationComponent
        # `capture` hands back a photo, so the camera is only offered when nothing
        # but images are accepted -- never on a CSV or PDF field.
        IMAGE_EXTENSIONS = ApplicationUploader::IMAGE_EXT_WHITE_LIST.map { ".#{it}" }.freeze

        def initialize(form_builder:, attribute:, accept: nil, button_text: nil, camera: nil, camera_text: nil,
          multiple: false, placeholder: nil, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @button_text = button_text || translation(".choose_file")
          @camera_text = camera_text || translation(".take_picture")
          @drop_text = translation(".drop_file", count: multiple ? 2 : 1)
          @placeholder = placeholder || translation(".no_file_chosen")

          accept_list = Array(accept).flat_map { it.to_s.split(",") }.filter_map { it.strip.presence }
          @camera = camera.nil? ? accept_list.any? && accept_list.all? { image?(it) } : camera

          @html_options = {
            class: "tw:peer tw:sr-only",
            accept: accept_list.join(",").presence,
            multiple:,
            data: {"form--file-upload-target": "input", action: "form--file-upload#display"}
          }.merge(html_options)

          # Style the label as a UI::Button; the focus ring is driven by the peer (sr-only) input.
          @label_classes = UI::Button::Component.build_classes(color: :secondary, size: :md, html_class: "tw:whitespace-nowrap tw:peer-focus-visible:ring-3 tw:peer-focus-visible:ring-blue-500/40")
        end

        private

        def image?(accept_entry)
          accept_entry.start_with?("image/") || IMAGE_EXTENSIONS.include?(accept_entry.downcase)
        end
      end
    end
  end
end
