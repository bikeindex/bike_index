# frozen_string_literal: true

module UI
  module Forms
    module FileUpload
      class Component < ApplicationComponent
        # mb-0 cancels legacy bootstrap's `label` margin, which items-center would
        # otherwise center along with the button next to it.
        LABEL_CLASSES = "tw:mb-0 tw:whitespace-nowrap tw:peer-focus-visible:ring-3 tw:peer-focus-visible:ring-blue-500/40"

        def initialize(form_builder:, attribute:, accept: nil, camera: nil, direct_upload: false, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @placeholder = translation(".no_file_chosen")

          accept_list = Array(accept).flat_map { it.to_s.split(",") }.filter_map { it.strip.presence }
          # `capture` hands back a photo, so the camera is only offered when nothing
          # but images are accepted -- never on a CSV or PDF field.
          @camera = camera.nil? ? accept_list.any? && accept_list.all? { image?(it) } : camera

          @attachment_url = attached_url
          @thumbnail_url = thumbnail_version_url || @attachment_url

          # The browser uploads to storage itself and the form carries the blob's signed id,
          # so the field is nameless - it must not also post the bytes
          @direct_upload = direct_upload
          @html_options = {
            class: "tw:peer tw:sr-only",
            accept: accept_list.join(",").presence,
            data: {"ui--forms--file-upload-target": "input", action: "ui--forms--file-upload#display"}
          }.merge(html_options)
          @html_options[:name] = nil if direct_upload

          # Style the label as a UI::Button; the focus ring is driven by the peer (sr-only) input.
          @label_classes = UI::Button::Component.build_classes(color: :secondary, size: :md, html_class: LABEL_CLASSES)
        end

        private

        # Both wordings ship and the pointer media query picks one -- a coarse pointer
        # can neither click nor drop, so it gets the short one.
        def label_content
          safe_join([
            tag.span(translation(".choose_or_drop_file"), class: "tw:pointer-coarse:hidden"),
            tag.span(translation(".choose_file"), class: "tw:hidden tw:pointer-coarse:inline")
          ])
        end

        def image?(accept_entry)
          accept_entry.start_with?("image/") || ApplicationUploader.permitted_extensions.include?(accept_entry.downcase)
        end

        def record
          @form_builder.object
        end

        def attachment
          record.try(@attribute)
        end

        # The record's own `<attribute>_url` wins where it defines one -- several add a
        # dev fallback or serve a processed copy that reaching for the blob would skip.
        def attached_url
          return unless attached?

          record.respond_to?(:"#{@attribute}_url") ? record.public_send(:"#{@attribute}_url") : BlobUrl.for(attachment.blob)
        end

        # Keyed off the uploader rather than a `<attribute>?` predicate, which would also
        # match a boolean column of the same name. CarrierWave hands one back either way.
        def attached?
          return false if record.blank?
          return attachment.present? if attachment.respond_to?(:versions)

          attachment.respond_to?(:attached?) && attachment.attached?
        end

        # Only CarrierWave has versions, and which is smallest is the uploader's to say.
        def thumbnail_version_url
          return unless @attachment_url && attachment.respond_to?(:versions)

          version = attachment.class.thumbnail_version
          attachment.url(version) if version
        end
      end
    end
  end
end
