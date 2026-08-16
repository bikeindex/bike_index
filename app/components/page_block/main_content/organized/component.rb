# frozen_string_literal: true

module PageBlock
  module MainContent
    module Organized
      # The organization admin shell - the left menu, and the content column it's
      # positioned over
      class Component < ApplicationComponent
        def initialize(current_organization:, current_user:, passive_organization:,
          unregistered_parking_notification:, show_general_alert:, controller_namespace:,
          controller_name:, action_name:)
          @current_organization = current_organization
          @current_user = current_user
          @passive_organization = passive_organization
          @unregistered_parking_notification = unregistered_parking_notification
          @show_general_alert = show_general_alert
          @controller_namespace = controller_namespace
          @controller_name = controller_name
          @action_name = action_name
        end
      end
    end
  end
end
