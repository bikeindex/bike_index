# frozen_string_literal: true

module UI
  module Forms
    module FileUpload
      class Component < ApplicationComponent
        # `capture` hands back a photo, so the camera is only offered when nothing
        # but images are accepted -- never on a CSV or PDF field.
        IMAGE_ACCEPT = /\Aimage\/|\A\.(avif|gif|heic|jpe?g|png|tiff?|webp)\z/i

        def initialize(form_builder:, attribute:, accept: nil, button_text: nil, camera: nil, camera_text: nil, placeholder: nil, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @button_text = button_text || translation(".choose_file")
          @camera_text = camera_text || translation(".take_picture")
          @drop_text = translation(html_options[:multiple] ? ".drop_files" : ".drop_file")
          @placeholder = placeholder || translation(".no_file_chosen")

          accept_list = Array(accept).join(",").split(",").map(&:strip).reject(&:empty?)
          @camera = camera.nil? ? accept_list.any? && accept_list.all? { |type| IMAGE_ACCEPT.match?(type) } : camera
          # The camera button is what sets `capture`, so only it needs the reset.
          @label_data = @camera ? {action: "click->form--file-upload#chooseFile"} : {}

          @html_options = {
            class: "tw:peer tw:sr-only",
            accept: accept_list.join(",").presence,
            data: {"form--file-upload-target": "input", action: "form--file-upload#display"}
          }.merge(html_options)

          # Style the label as a UI::Button; the focus ring is driven by the peer (sr-only) input.
          @label_classes = UI::Button::Component.build_classes(color: :secondary, size: :md, html_class: "tw:whitespace-nowrap tw:peer-focus-visible:ring-3 tw:peer-focus-visible:ring-blue-500/40")
        end
      end
    end
  end
end
