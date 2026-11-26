# frozen_string_literal: true

module Atoms
  module Org
    module RegistrationLink
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Atoms::Org::RegistrationLink::Component.new(organization: Organization.example))
        end
      end
    end
  end
end
