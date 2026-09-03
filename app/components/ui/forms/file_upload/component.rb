# frozen_string_literal: true

module UI
  module Forms
    module FileUpload
      # direct_upload_url: with JS, uploads on pick and posts the blob's signed id instead of
      # the bytes. The field still renders as an ordinary one, so it posts the file when JS
      # doesn't run - the controller drops its name only once it's driving the upload.
      class Component < ApplicationComponent
        # mb-0 cancels legacy bootstrap's `label` margin, which items-center would
        # otherwise center along with the button next to it.
        LABEL_CLASSES = "tw:mb-0 tw:whitespace-nowrap tw:peer-focus-visible:ring-3 tw:peer-focus-visible:ring-blue-500/40"

        def initialize(form_builder:, attribute:, accept: nil, camera: nil, direct_upload_url: nil, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @placeholder = translation(".no_file_chosen")

          accept_list = Array(accept).flat_map { it.to_s.split(",") }.filter_map { it.strip.presence }
          # `capture` hands back a photo, so the camera is only offered when nothing
          # but images are accepted -- never on a CSV or PDF field.
          @camera = camera.nil? ? accept_list.any? && accept_list.all? { image?(it) } : camera

          @attachment_url = attached_url
          @thumbnail_url = thumbnail_version_url || @attachment_url

          @direct_upload_url = direct_upload_url
          # Carries the blob the browser uploaded. Scoped to the form builder like every other
          # field here, so two of these on one page don't collide on the same param
          @signed_id_field = "#{form_builder.object_name}[#{attribute}_signed_id]" if direct_upload_url.present?
          @html_options = {
            class: "tw:peer tw:sr-only",
            accept: accept_list.join(",").presence,
            data: {"ui--forms--file-upload-target": "input", action: "ui--forms--file-upload#display"}
          }.merge(html_options)

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
