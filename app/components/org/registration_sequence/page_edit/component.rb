# frozen_string_literal: true

module Org
  module RegistrationSequence
    module PageEdit
      class Component < ApplicationComponent
        def initialize(form_builder:)
          @form_builder = form_builder
        end

        private

        # One editable row per bullet, with an empty row so a blank page has somewhere to type
        def bullets
          @form_builder.object.bullets.presence || [""]
        end

        # Registrants see this page's rules badged with the organization's name
        def organization_name
          @form_builder.object.registration_sequence&.organization&.short_name
        end
      end
    end
  end
end
