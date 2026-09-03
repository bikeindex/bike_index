# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module Form
        module LocationFields
          class Component < ApplicationComponent
            def initialize(form_builder:, organization:)
              @form_builder = form_builder
              @organization = organization
              @location = form_builder.object
            end

            private

            def checkbox(attribute, label = Location.human_attribute_name(attribute))
              render(UI::Forms::Checkbox::Component.new(form_builder: @form_builder, attribute:,
                label:, class_name: "tw:mb-2"))
            end

            def publicly_visible_label
              return Location.human_attribute_name(:publicly_visible) if @organization.allowed_show?

              safe_join([Location.human_attribute_name(:publicly_visible),
                tag.small("org not shown on map, checking this won't change that", class: "text-warning ml-1")], " ")
            end
          end
        end
      end
    end
  end
end
