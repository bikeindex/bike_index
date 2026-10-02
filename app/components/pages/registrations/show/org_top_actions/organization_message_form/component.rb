# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module OrganizationMessageForm
          class Component < ApplicationComponent
            def initialize(bike:, organization:)
              @bike = bike
              @organization = organization
            end
          end
        end
      end
    end
  end
end
