# frozen_string_literal: true

module Admin
  module Headers
    module CurrentInfo
      class Component < ApplicationComponent
        HEADER_KEYS = %i[
          organization_id
          primary_activity
          search_bike_id
          search_kind
          search_marketplace_listing_id
          search_membership_id
          user_id
          search_strava_integration_id
        ].freeze

        def initialize(index:, viewing:)
          @index = index
          @viewing = viewing
        end

        def render?
          (@index.params.keys.map(&:to_sym) & HEADER_KEYS).any? || show_user? || show_marketplace_listing? ||
            show_organization?
        end

        private

        def show_user?
          @index.user_subject.present? || @index.params[:user_id].present?
        end

        def show_bike?
          bike_subject.present? || @index.params[:search_bike_id].present?
        end

        def bike_subject
          @bike_subject ||= @index.bike || Bike.unscoped.find_by_id(@index.params[:search_bike_id])
        end

        def show_marketplace_listing?
          @index.params[:search_marketplace_listing_id].present? || @index.marketplace_listing.present?
        end

        def marketplace_listing_subject
          @index.marketplace_listing || MarketplaceListing.find_by_id(@index.params[:search_marketplace_listing_id])
        end

        def show_organization?
          @index.params[:organization_id].present? || organization_subject.present?
        end

        def organization_subject
          @index.current_organization
        end

        def show_membership?
          membership_id.present?
        end

        def membership_id
          @index.params[:search_membership_id]
        end

        def show_kind?
          @index.params[:search_kind].present?
        end

        def show_strava_integration?
          strava_integration_id.present?
        end

        def strava_integration_id
          @index.params[:search_strava_integration_id]
        end

        def strava_integration
          return @strava_integration if defined?(@strava_integration)

          @strava_integration = StravaIntegration.find_by_id(strava_integration_id)
        end

        def kind_humanized = @index.params[:search_kind]&.humanize

        def show_primary_activity?
          @index.params[:primary_activity].present? || primary_activity_subject.present?
        end

        def primary_activity_subject
          @primary_activity_subject ||= @index.primary_activity || PrimaryActivity.find_by_id(@index.params[:primary_activity])
        end

        def error_text_class
          UI::Alerts::Base::Component::TEXT_CLASSES[:error]
        end
      end
    end
  end
end
