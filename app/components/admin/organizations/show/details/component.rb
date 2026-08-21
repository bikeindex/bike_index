# frozen_string_literal: true

module Admin
  module Organizations
    module Show
      module Details
        # The organization's identity — name, kind, slug, when it was created.
        class Component < ApplicationComponent
          def initialize(organization:)
            @organization = organization
          end
        end
      end
    end
  end
end
