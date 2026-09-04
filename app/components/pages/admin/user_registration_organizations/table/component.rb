# frozen_string_literal: true

module Pages
  module Admin
    module UserRegistrationOrganizations
      module Table
        class Component < ApplicationComponent
          def initialize(user_registration_organizations:, sort_state: ComponentStructs::SortState.new,
            render_sortable: false, render_search: true)
            @user_registration_organizations = user_registration_organizations
            @sort_state = sort_state
            @render_sortable = render_sortable
            @render_search = render_search
          end
        end
      end
    end
  end
end
