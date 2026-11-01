# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Bikes
        # The body of the user's bikes and deleted bikes tabs
        class Component < ApplicationComponent
          TABS = %i[bikes deleted_bikes].freeze

          def initialize(user:, active_tab:, bikes:, pagy:)
            raise_if_invalid_value!(:active_tab, active_tab, TABS)

            @user = user
            @active_tab = active_tab
            @bikes = bikes
            @pagy = pagy
          end

          private

          def index_path
            if @active_tab == :deleted_bikes
              admin_bikes_path(user_id: @user.id, search_status_deleted_only: true, search_status_example: true)
            else
              admin_bikes_path(user_id: @user.id)
            end
          end
        end
      end
    end
  end
end
