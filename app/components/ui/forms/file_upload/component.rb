# frozen_string_literal: true

module UI
  module Forms
    module FileUpload
      class Component < ApplicationComponent
        def initialize(form_builder:, attribute:, accept: nil, button_text: nil, camera: nil, camera_text: nil,
          multiple: false, placeholder: nil, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @button_text = button_text || translation(".choose_file")
          @camera_text = camera_text || translation(".take_picture")
          @drop_text = translation(".drop_file", count: multiple ? 2 : 1)
          @placeholder = placeholder || translation(".no_file_chosen")

          accept_list = Array(accept).flat_map { it.to_s.split(",") }.filter_map { it.strip.presence }
          # `capture` hands back a photo, so the camera is only offered when nothing
          # but images are accepted -- never on a CSV or PDF field.
          @camera = camera.nil? ? accept_list.any? && accept_list.all? { image?(it) } : camera

          @attachment_url = attached_url
          @thumbnail_url = thumbnail_version_url || @attachment_url

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
          accept_entry.start_with?("image/") || ApplicationUploader.permitted_extensions.include?(accept_entry.downcase)
        end

        def record
          @form_builder.object
        end

        # The attached file, or nil. CarrierWave's `<attribute>_url` falls back to a
        # placeholder, so presence comes from its `<attribute>?` predicate; ActiveStorage
        # answers `attached?`. Either way the record's own `<attribute>_url` wins when it
        # defines one -- several add a dev fallback or serve a processed copy.
        def attached_url
          return unless attached?

          record.respond_to?(:"#{@attribute}_url") ? record.public_send(:"#{@attribute}_url") : BlobUrl.for(attachment.blob)
        end

        def attached?
          return false if record.blank?
          return record.public_send(:"#{@attribute}?") if record.respond_to?(:"#{@attribute}?")

          attachment.respond_to?(:attached?) && attachment.attached?
        end

        def attachment
          record.try(@attribute)
        end

        # Only CarrierWave has versions, and which one is smallest is the uploader's to say.
        def thumbnail_version_url
          return unless @attachment_url && attachment.respond_to?(:versions)

          version = attachment.class.thumbnail_version
          attachment.url(version) if version
        end
      end
    end
  end
end
