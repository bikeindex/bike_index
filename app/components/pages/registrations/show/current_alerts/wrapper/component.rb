# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module Wrapper
          # The alerts about the registration's current state, in both views. The token
          # prompt is the alert here — its dialog renders outside the page's fragment cache
          class Component < ApplicationComponent
            def initialize(bike:, current_user: nil, bike_sticker: nil, owner: false, organization: nil,
              current_alerts: {})
              @bike = bike
              @current_user = current_user
              @bike_sticker = bike_sticker
              @owner = owner
              @organization = organization
              @current_alerts = current_alerts
            end

            def call
              safe_join(alerts.map { |alert| render(alert) })
            end

            # An alert carrying state the bike's own cache version misses declares it, and
            # the page wrapper folds this into the key of the fragment they render inside
            def cache_version
              alerts.flat_map { |alert| alert.try(:cache_version) || [] }
            end

            private

            # Each renders itself or nothing, so this is only the order they stack in
            def alerts
              @alerts ||= [
                TokenPrompt::Component.new(bike: @bike, current_user: @current_user,
                  current_alerts: @current_alerts, variant: :alert),
                ScannedSticker::Component.new(bike: @bike, bike_sticker: @bike_sticker, current_user: @current_user),
                SentToNewOwner::Component.new(bike: @bike, owner: @owner),
                ClaimImpound::Component.new(bike: @bike, current_user: @current_user, owner: @owner,
                  organization: @organization)
              ]
            end
          end
        end
      end
    end
  end
end
