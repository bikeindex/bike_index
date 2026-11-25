# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module Show
        module Account
          # The organization's account — its auto user, invites, website and POS integration.
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
