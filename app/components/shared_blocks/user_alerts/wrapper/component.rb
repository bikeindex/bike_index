# frozen_string_literal: true

module SharedBlocks
  module UserAlerts
    module Wrapper
      # The general alert shown below the navbar on every page. Only ever one: the first
      # kind the user has wins, even when it turns out to have nothing to show
      class Component < ApplicationComponent
        # container lines it up with the navbar above; z-20 because the homepage and
        # landing page bike tile grids are positioned, so they'd otherwise paint over
        # this in-flow banner; general-alert is what the landing pages hang their own
        # spacing on
        def initialize(current_user:, wrapper_class: "general-alert container tw:relative tw:z-20")
          @current_user = current_user
          @wrapper_class = wrapper_class
        end

        # Memoized, and deferring to the kind's own component, so the layout can ask
        # whether an alert is really going to show before it makes room for one
        def render?
          return @render if defined?(@render)

          @render = @current_user.present? && alert_component&.render?
        end

        def call
          tag.div(render(alert_component), class: @wrapper_class)
        end

        private

        def alert_component
          @alert_component ||= case alert_kind
          when "phone_waiting_confirmation" then phone_waiting_confirmation_component
          when "stolen_bike_without_location"
            StolenBikeWithoutLocation::Component.new(bikes: stolen_bikes(:without_street?))
          when "theft_alert_without_photo"
            TheftAlertWithoutPhoto::Component.new(bikes: stolen_bikes(:theft_alert_missing_photo?))
          when "unfinished_registration"
            UnfinishedRegistration::Component.new(b_param: unfinished_b_param, current_user: @current_user)
          end
        end

        def alert_kind
          (UserAlert.general_kinds - UserAlert.disabled_kinds)
            .find { |kind| @current_user.alert_slugs.include?(kind) }
        end

        # TODO: use existing user_alert to select correct phone
        def phone_waiting_confirmation_component
          user_phone = @current_user.user_phones.waiting_confirmation.reorder(:updated_at).last
          # The slug is stale, so enqueue a job to update the user. Enqueuing doesn't write
          # to the DB, so it can be performed by a read replica
          if user_phone.blank?
            @current_user.skip_update = false # required for testing
            @current_user.perform_user_update_jobs
          end

          PhoneWaitingConfirmation::Component.new(user_phone:)
        end

        def unfinished_b_param
          @current_user.user_alerts.active.unfinished_registration
            .reorder(:updated_at).last&.alertable
        end

        # TODO: use existing user_alert to select correct bikes
        def stolen_bikes(matcher)
          @current_user.bikes.status_stolen.includes(:current_stolen_record)
            .select { |bike| bike.current_stolen_record&.send(matcher) }
        end
      end
    end
  end
end
