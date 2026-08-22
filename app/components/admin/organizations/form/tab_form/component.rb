# frozen_string_literal: true

module Admin
  module Organizations
    module Form
      module TabForm
        # The form every organization tab submits, around whichever slice of it the tab
        # renders. tab: tells update which tab to return to, and which fields were on the
        # page - a new organization has no tab, so it submits all of them.
        #
        # fields_component: rather than block content, the way UI::Forms::NestedFields takes
        # its fields - the form builder doesn't exist until form_for yields it.
        class Component < ApplicationComponent
          def initialize(organization:, fields_component:, fields_args: {}, tab: nil,
            submit_text: "Update", width: :form)
            @organization = organization
            @fields_component = fields_component
            @fields_args = fields_args
            @tab = tab
            @submit_text = submit_text
            @width = width
          end
        end
      end
    end
  end
end
