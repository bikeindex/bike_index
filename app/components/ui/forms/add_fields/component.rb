# frozen_string_literal: true

module UI
  module Forms
    module AddFields
      # The "add another" link for a nested-attributes association. It carries a blank set of the
      # association's fields, which ui--forms--add-fields inserts ahead of the link on click.
      #
      # `fields` is called with the new record's form builder and returns its markup.
      class Component < ApplicationComponent
        CONTROLLER = "ui--forms--add-fields"
        # ui--forms--add-fields swaps this for a unique index, matching the placeholder
        # bullet_editors uses
        CHILD_INDEX = "__INDEX__"

        def initialize(name:, form_builder:, association:, fields:, class_name: nil, obj_attrs: {})
          @name = name
          @form_builder = form_builder
          @association = association
          @fields = fields
          @class_name = class_name
          @obj_attrs = obj_attrs
        end

        def call
          link_to(@name, "#", class: @class_name,
            data: {controller: CONTROLLER, action: "click->#{CONTROLLER}#add", "#{CONTROLLER}-fields-value": blank_fields})
        end

        private

        def blank_fields
          new_object = @form_builder.object.send(@association).klass.new(@obj_attrs)
          @form_builder.fields_for(@association, new_object, child_index: CHILD_INDEX, &@fields)
        end
      end
    end
  end
end
