# frozen_string_literal: true

module Pages
  module Admin
    module IndexSkeleton
      module IndexInfo
        # What an index is filtered down to, one row per subject, each with a link dropping it
        class Component < ApplicationComponent
          def initialize(index:, viewing:)
            @index = index
            @viewing = viewing
          end

          def render? = rows.any?

          private

          def rows
            @rows ||= [user_row, bike_row, marketplace_listing_row, organization_row, membership_row,
              strava_integration_row, kind_row, primary_activity_row].compact
          end

          def viewing_for(*subject) = safe_join([@viewing.pluralize, " for ", *subject])

          def missing(*subject)
            tag.span(safe_join([*subject, " ", tag.em("missing")]), class: error_text_class)
          end

          def error_text_class = UI::Alerts::Base::Component::TEXT_CLASSES[:error]

          def user_row
            user = @index.user_subject
            return unless user.present? || @index.params[:user_id].present?

            {view_all_text: "view for all users", key: :user_id,
             subject: user.present? ? viewing_for(link_to(user.display_name, admin_user_path(user), class: "twlink")) : missing("User ##{@index.params[:user_id]}")}
          end

          def bike_row
            bike = @index.bike || Bike.unscoped.find_by_id(@index.params[:search_bike_id])
            return unless bike.present? || @index.params[:search_bike_id].present?

            {view_all_text: "view for all bikes", key: :search_bike_id,
             subject: bike.present? ? viewing_for(link_to(bike.title_string, admin_bike_path(bike), class: "twlink")) : missing("Bike ##{@index.params[:search_bike_id]}"),
             detail: render(Pages::Admin::Bikes::DeletedAlert::Component.new(bike:))}
          end

          def marketplace_listing_row
            id = @index.params[:search_marketplace_listing_id]
            listing = @index.marketplace_listing || MarketplaceListing.find_by_id(id)
            return unless id.present? || listing.present?

            {view_all_text: "view for all marketplace listings", key: :search_marketplace_listing_id,
             subject: listing.present? ? viewing_for(marketplace_listing_subject(listing)) : missing("Marketplace ##{id}")}
          end

          def marketplace_listing_subject(listing)
            badge = render(Atoms::Admin::Badges::MarketplaceListing::Component.new(status: listing.status, status_humanized: listing.status_humanized, kind: :marketplace_listing))

            safe_join([tag.em(safe_join(["Marketplace Listing ", badge, " ##{listing.id},"])), " ",
              render(Atoms::Admin::TableCells::Bike::Component.new(bike: listing.item, bike_id: listing.item_id))])
          end

          def organization_row
            organization = @index.current_organization
            return unless @index.params[:organization_id].present? || organization.present?

            {view_all_text: "view for all organizations", key: :organization_id,
             subject: viewing_for(organization.present? ? tag.em(link_to(organization.short_name, admin_organization_path(organization), class: "twlink")) : tag.strong("no organization")),
             detail: (organization_deleted(organization) if organization&.deleted?)}
          end

          def organization_deleted(organization)
            tag.em(class: "twless-strong tw:mt-1 tw:block") do
              safe_join(["(#{organization.short_name} is ", tag.em("deleted", class: error_text_class), ") - at ",
                render(UI::Time::Component.new(time: organization.deleted_at, format: :localize_time_precise))])
            end
          end

          def membership_row
            id = @index.params[:search_membership_id]
            return if id.blank?

            {view_all_text: "view for all memberships", key: :search_membership_id,
             subject: viewing_for(link_to("Membership #{id}", admin_membership_path(id), class: "twlink"))}
          end

          def strava_integration_row
            id = @index.params[:search_strava_integration_id]
            return if id.blank?

            integration = StravaIntegration.find_by_id(id)
            user = if integration.present?
              tag.small(safe_join(["for ", render(Atoms::Admin::TableCells::User::Component.new(user: integration.user, user_id: integration.user_id, user_link_path: admin_strava_integration_path(id)))]))
            end

            {view_all_text: "view for all Strava integrations", key: :search_strava_integration_id,
             subject: viewing_for(link_to("Strava Integration #{id}", admin_strava_integration_path(id), class: "twlink"), " ", user)}
          end

          def kind_row
            kind = @index.params[:search_kind]
            return if kind.blank?

            {view_all_text: "view for all kinds", key: :search_kind, subject: viewing_for(tag.strong(kind.humanize))}
          end

          def primary_activity_row
            param = @index.params[:primary_activity]
            activity = @index.primary_activity || PrimaryActivity.find_by_id(param)
            return unless param.present? || activity.present?

            {view_all_text: "view for all primary activities", key: :primary_activity,
             subject: activity.present? ? viewing_for(link_to(activity.name, admin_primary_activity_path(activity), class: "twlink")) : tag.span(%(unknown primary activity "#{param}"), class: error_text_class)}
          end
        end
      end
    end
  end
end
