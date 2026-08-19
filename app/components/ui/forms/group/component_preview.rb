# frozen_string_literal: true

module UI
  module Forms
    module Group
      class ComponentPreview < ApplicationComponentPreview
        # @!group Kinds
        def text_field
          {template: "ui/forms/group/component_preview/text_field"}
        end

        def text_area
          {template: "ui/forms/group/component_preview/text_area"}
        end

        def content_block
          {template: "ui/forms/group/component_preview/content_block"}
        end

        def select
          {template: "ui/forms/group/component_preview/select"}
        end

        def combobox
          {template: "ui/forms/group/component_preview/combobox"}
        end

        def radio_button_group
          {template: "ui/forms/group/component_preview/radio_button_group"}
        end

        def file_upload
          {template: "ui/forms/group/component_preview/file_upload"}
        end

        def custom_label
          {template: "ui/forms/group/component_preview/custom_label"}
        end

        def helper_text
          {template: "ui/forms/group/component_preview/helper_text"}
        end

        def prefix
          {template: "ui/forms/group/component_preview/prefix"}
        end
        # @!endgroup
      end
    end
  end
end
