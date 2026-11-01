# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        module Payments
          # The user's Payments tab, under their memberships when they've ever had one
          class Component < ApplicationComponent
            def initialize(user:)
              @user = user
            end

            private

            def memberships
              @memberships ||= Pages::Admin::Users::Tabs::Component.records(@user, :memberships)
                .includes(:creator, :stripe_subscriptions).reorder(id: :desc).to_a
            end

            def payments
              @payments ||= Pages::Admin::Users::Tabs::Component.records(@user, :payments)
                .includes(:organization, :invoice).reorder(created_at: :desc).to_a
            end
          end
        end
      end
    end
  end
end
