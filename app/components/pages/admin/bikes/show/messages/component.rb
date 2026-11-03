# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module Show
        module Messages
          # Everything sent about one registration, on the bike's Messages tab. Each section
          # is a count that links to its own index, filtered to this bike.
          class Component < ApplicationComponent
            def initialize(bike:)
              @bike = bike
            end

            private

            def notifications
              @notifications ||= @bike.notifications.includes(:notifiable).order(created_at: :desc)
            end

            def organization_messages
              @organization_messages ||= @bike.organization_messages.includes(:organization, :sender, :receiver)
                .order(created_at: :desc)
            end

            def feedbacks = @feedbacks ||= Feedback.bike(@bike.id).order(created_at: :desc)

            def user_alerts = @user_alerts ||= UserAlert.where(bike_id: @bike.id).order(created_at: :desc)

            def parking_notifications
              @parking_notifications ||= @bike.parking_notifications.order(created_at: :desc)
            end

            def graduated_notifications_count
              @graduated_notifications_count ||= GraduatedNotification.where(bike_id: @bike.id).count
            end
          end
        end
      end
    end
  end
end
