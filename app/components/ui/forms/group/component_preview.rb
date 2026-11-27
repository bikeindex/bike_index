# frozen_string_literal: true

module UI
  module Forms
    module Group
      # The groups' contents are checked by spec/components/ui/forms/group/component_preview_spec.rb
      class ComponentPreview < ApplicationComponentPreview
        # @!group All field types
        def text_field
          {template: "ui/forms/group/component_preview/text_field"}
        end

        def text_area
          {template: "ui/forms/group/component_preview/text_area"}
        end

        def number_field
          input_kind(:number_field, :year)
        end

        def telephone_field
          input_kind(:telephone_field, :phone)
        end

        def datetime_local_field
          input_kind(:datetime_local_field, :starts_at)
        end

        def website_field
          input_kind(:website_field, :website)
        end

        def postal_code_field
          input_kind(:postal_code_field, :postal_code)
        end

        def email
          {template: "ui/forms/group/component_preview/email"}
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

        def combobox_state
          {template: "ui/forms/group/component_preview/combobox_state"}
        end

        def combobox_manufacturer
          {template: "ui/forms/group/component_preview/combobox_manufacturer"}
        end

        def checkbox
          {template: "ui/forms/group/component_preview/checkbox"}
        end

        def radio_button_group
          {template: "ui/forms/group/component_preview/radio_button_group"}
        end

        def range
          {template: "ui/forms/group/component_preview/range"}
        end

        def file_upload
          {template: "ui/forms/group/component_preview/file_upload"}
        end

        def file_upload_multiple
          {template: "ui/forms/group/component_preview/file_upload_multiple"}
        end

        def address_group
          {template: "ui/forms/group/component_preview/address_group"}
        end

        def custom_label
          {template: "ui/forms/group/component_preview/custom_label"}
        end

        def helper_text
          {template: "ui/forms/group/component_preview/helper_text"}
        end

        def label_note
          {template: "ui/forms/group/component_preview/label_note"}
        end

        def prefix
          {template: "ui/forms/group/component_preview/prefix"}
        end
        # @!endgroup

        # Every field the browser checks, each starting with a value its check refuses - submit to see why
        def validated
          {template: "ui/forms/group/component_preview/validated"}
        end

        private

        def input_kind(kind, attribute)
          {template: "ui/forms/group/component_preview/input_kind", locals: {kind:, attribute:}}
        end
      end
    end
  end
end
