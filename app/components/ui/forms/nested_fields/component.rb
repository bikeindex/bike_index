# frozen_string_literal: true

module UI
  module Forms
    module NestedFields
      # A nested-attributes association's whole editable collection: the saved records' fields, a
      # blank set in a <template>, and the link that adds it. Rendering all of them here is what
      # keeps an added record identical to a saved one.
      #
      # fields_component renders one record, and is passed `form_builder:` plus fields_args. Its
      # root element has to carry WRAPPER_CLASS and `data-new-record`, and it has to contain a
      # `_destroy` input and a remove trigger actioning `#remove` - Admin::OrganizationForm::
      # LocationFields is the worked example.
      class Component < ApplicationComponent
        CONTROLLER = "ui--forms--nested-fields"
        # ui--forms--nested-fields swaps this for a distinct index per added record
        CHILD_INDEX = "__INDEX__"
        WRAPPER_CLASS = "nested-fields-wrapper"

        def initialize(form_builder:, association:, fields_component:, add_label:,
          fields_args: {}, obj_attrs: {}, class_name: nil, add_class_name: nil)
          @form_builder = form_builder
          @association = association
          @fields_component = fields_component
          @add_label = add_label
          @fields_args = fields_args
          @obj_attrs = obj_attrs
          @class_name = class_name
          @add_class_name = add_class_name
        end

        private

        def saved_fields
          @form_builder.fields_for(@association) { |builder| record_fields(builder) }
        end

        def blank_fields
          new_object = @form_builder.object.send(@association).klass.new(@obj_attrs)
          @form_builder.fields_for(@association, new_object, child_index: CHILD_INDEX) do |builder|
            record_fields(builder)
          end
        end

        def record_fields(builder)
          render(@fields_component.new(form_builder: builder, **@fields_args))
        end

        def target_data(name) = {"#{CONTROLLER}-target": name}

        def add_link_data = {action: "click->#{CONTROLLER}#add"}
      end
    end
  end
end
