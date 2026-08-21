# frozen_string_literal: true

module Admin
  module Organizations
    module Show
      module Account
        # The organization's account — its auto user, invites, website and POS integration.
        class Component < ApplicationComponent
          def initialize(organization:)
            @organization = organization
          end
        end
      end
    end
  end
end
