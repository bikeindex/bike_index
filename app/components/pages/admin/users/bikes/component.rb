# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Bikes
        # The body of the user's bikes tab
        class Component < ApplicationComponent
          def initialize(user:, bikes:, pagy:)
            @user = user
            @bikes = bikes
            @pagy = pagy
          end

          private

          def deleted_bikes_count = @deleted_bikes_count ||= Bike.unscoped.current_owner(@user.id).only_deleted.count
        end
      end
    end
  end
end
