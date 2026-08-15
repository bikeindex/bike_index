# frozen_string_literal: true

module UI
  module Forms
    module AddFields
      # The "add another" link for a nested-attributes association. It carries a blank set of the
      # association's fields, which ui--forms--add-fields inserts ahead of the link on click.
      #
      # `fields` is called with the new record's form builder and returns its markup - pair it
      # with a component that renders one record's fields, and render the same thing inside
      # the form's own fields_for so an added record matches the saved ones.
      class Component < ApplicationComponent
        CONTROLLER = "ui--forms--add-fields"

        def initialize(name:, form_builder:, association:, fields:, class_name: nil, obj_attrs: {})
          @name = name
          @form_builder = form_builder
          @association = association
          @fields = fields
          @class_name = class_name
          @obj_attrs = obj_attrs
        end

        def call
          link_to(@name, "#", class: @class_name, data: controller_data)
        end

        private

        def controller_data
          {controller: CONTROLLER,
           action: "click->#{CONTROLLER}#add",
           "#{CONTROLLER}-fields-value": blank_fields,
           "#{CONTROLLER}-child-index-value": child_index}
        end

        def new_object
          @new_object ||= @form_builder.object.send(@association).klass.new(@obj_attrs)
        end

        # The controller swaps this for a unique index, so it can't collide with anything else
        # the fields contain - an object_id is long enough not to
        def child_index = new_object.object_id

        def blank_fields
          @form_builder.fields_for(@association, new_object, child_index:) { |builder| @fields.call(builder) }
        end
      end
    end
  end
end
