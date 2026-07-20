# frozen_string_literal: true

module UI
  module Forms
    module Group
      class ComponentPreview < ApplicationComponentPreview
        # @!group Kinds
        def text_field
          {template: "ui/forms/group/component_preview/text_field"}
        end

        def email_field
          {template: "ui/forms/group/component_preview/email_field"}
        end

        def text_area
          {template: "ui/forms/group/component_preview/text_area"}
        end

        def check_box
          {template: "ui/forms/group/component_preview/check_box"}
        end

        def content_block
          {template: "ui/forms/group/component_preview/content_block"}
        end

        def file_upload
          {template: "ui/forms/group/component_preview/file_upload"}
        end

        def custom_label
          {template: "ui/forms/group/component_preview/custom_label"}
        end
        # @!endgroup
      end
    end
  end
end
