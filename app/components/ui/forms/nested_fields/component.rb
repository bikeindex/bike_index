# frozen_string_literal: true

module UI
  module Forms
    module NestedFields
      # Rendering the saved records, the blank set and the add button together is what keeps an
      # added record identical to a saved one.
      #
      # fields_component renders one record into the wrapper this builds, and owes it a
      # `_destroy` input and a remove trigger actioning `#remove`.
      # UI::Forms::NestedFields::PreviewFields is the minimal example.
      class Component < ApplicationComponent
        CONTROLLER = "ui--forms--nested-fields"
        # ui--forms--nested-fields swaps this for a distinct index per added record
        CHILD_INDEX = "__INDEX__"
        WRAPPER_CLASS = "nested-fields-wrapper"
        private_constant :CHILD_INDEX, :WRAPPER_CLASS

        def initialize(form_builder:, association:, fields_component:, add_label:, fields_args: {},
          fields_class_name: nil, obj_attrs: {}, class_name: nil, add_class_name: nil)
          @form_builder = form_builder
          @association = association
          @fields_component = fields_component
          @add_label = add_label
          @fields_args = fields_args
          @fields_class_name = fields_class_name
          @obj_attrs = obj_attrs
          @class_name = class_name
          @add_class_name = add_class_name
        end

        private

        def saved_fields
          @form_builder.fields_for(@association) { |builder| record_fields(builder) }
        end

        def blank_fields
          new_object = @form_builder.object.public_send(@association).klass.new(@obj_attrs)
          @form_builder.fields_for(@association, new_object, child_index: CHILD_INDEX) do |builder|
            record_fields(builder)
          end
        end

        # data-new-record is what tells #remove to detach rather than hide
        def record_fields(builder)
          tag.div(class: [WRAPPER_CLASS, @fields_class_name].compact.join(" "),
            data: {new_record: builder.object.new_record?}) do
            render(@fields_component.new(form_builder: builder, **@fields_args))
          end
        end

        def controller_data
          {controller: CONTROLLER, "#{CONTROLLER}-wrapper-selector-value": ".#{WRAPPER_CLASS}"}
        end

        def target_data(name) = {"#{CONTROLLER}-target": name}

        def add_button_data = {action: "click->#{CONTROLLER}#add"}
      end
    end
  end
end
