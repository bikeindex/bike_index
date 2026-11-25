# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module Show
        module Details
          # The organization's identity — name, kind, slug, when it was created.
          class Component < ApplicationComponent
            def initialize(organization:, display_dev_info: false)
              @organization = organization
              @display_dev_info = display_dev_info
            end
          end
        end
      end
    end
  end
end
