# frozen_string_literal: true

module Pages
  module Register
    module Step1Fields
      # What step 1 asks for, rendered into whichever form holds it - its own, or the
      # single-page flow's, where these sit above step 2's details
      class Component < ApplicationComponent
        def initialize(b_param:, form:, organization:, current_user: nil)
          @b_param = b_param
          @form = form
          @current_user = current_user
          @organization = organization
        end

        private

        def cycle_type
          @b_param.type
        end

        # Its own span, so register--heading can swap the word when the combobox changes
        def cycle_type_tag
          tag.span(cycle_type, data: {"register--heading-target": "cycleType"})
        end

        # owner_email is the setting bikes/new labels its email field with
        def email_label
          OrgServices::Displayer.registration_field_label(@organization, "owner_email", strip_tags: true) ||
            (translation(".email_school", org_name: @organization.short_name) if @organization&.school?) ||
            translation(".email")
        end

        def email_placeholder
          OrgServices::Displayer.registration_field_label(@organization, "email_placeholder", strip_tags: true) ||
            translation(".email_placeholder")
        end
      end
    end
  end
end
