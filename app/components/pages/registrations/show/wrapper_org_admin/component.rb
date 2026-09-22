# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module WrapperOrgAdmin
        class Component < ApplicationComponent
          # Template Dependency: Pages::Registrations::Show::ComponentList::Component
          # Template Dependency: Pages::Registrations::Show::CurrentAlerts::Wrapper::Component
          include BikeHelper

          OTHER_REGISTRATIONS_LIMIT = 10

          # org_role is what this renders as — a superadmin can view any org either way
          def initialize(bike:, current_user:, organization:, org_role:, available_views: [], bike_sticker: nil,
            current_alerts: {}, show_legacy: false, display_dev_info: false)
            @bike = bike
            @show_legacy = show_legacy
            @display_dev_info = display_dev_info
            @current_user = current_user
            @organization = organization
            @available_views = available_views
            @bike_sticker = bike_sticker
            @org_role = org_role
            @current_alerts = current_alerts
          end

          def render?
            @bike.present? && @organization.present? && @current_user.present? &&
              @current_user.authorized?(@organization) && @bike.visible_by?(@current_user)
          end

          # Records shown here that don't touch the bike, so its cache version misses them
          def cache_version
            [other_registrations.maximum(:updated_at), other_registrations_count,
              *current_alerts_component.cache_version]
          end

          private

          def current_alerts_component
            @current_alerts_component ||= CurrentAlerts::Wrapper::Component.new(bike: @bike,
              current_user: @current_user, bike_sticker: @bike_sticker, organization: @organization,
              current_alerts: @current_alerts)
          end

          def info_row(label, value = nil, &block)
            render(UI::DefinitionList::Row::Component.new(label:, value:, render_with_no_value: true, no_value_text: "-"), &block)
          end

          def staff?
            @org_role == :staff
          end

          def organization_registered?
            return @organization_registered if defined?(@organization_registered)

            @organization_registered = @bike.organized?(@organization)
          end

          def unregistered?
            @bike.unregistered_parking_notification?
          end

          # Contact and law-enforcement data: full staff only, on their own org's bike
          def show_contact?
            staff? && organization_registered?
          end

          def role_label
            staff? ? translation(".role_staff") : translation(".role_limited")
          end

          def org_chip_color
            organization_registered? ? :purple : :warning
          end

          def contact_blocked_title
            organization_registered? ? translation(".restricted_title") : translation(".not_registered_title", org_name: @organization.short_name)
          end

          def contact_blocked_message
            organization_registered? ? translation(".restricted_message") : translation(".not_registered_message", org_name: @organization.short_name)
          end

          def title
            bike_title_html(@bike)
          end

          def subtitle
            @subtitle ||= render(Pages::Registrations::Show::Subtitle::Component.new(bike: @bike)).presence
          end

          def owner_phone
            @bike.phone if @bike.phoneable_by?(@current_user, @organization)
          end

          # The address renders its own row
          def owner_reg_field_rows
            OrgServices::RegistrationFields.rows(bike: @bike, organization: @organization,
              reg_fields: OrgServices::RegistrationFields::OWNER_ACCESS_REG_FIELDS - ["reg_address"])
          end

          def show_notes?
            @organization.enabled?("registration_notes")
          end

          def bike_organization_note
            @bike_organization_note ||= BikeOrganizationNote.find_by(bike_id: @bike.id, organization_id: @organization.id)
          end

          def notes_url
            organization_bike_path(@bike, organization_id: @organization.to_param)
          end

          def edit_access_path
            edit_bike_path(@bike, edit_template: @bike.default_edit_template)
          end

          # Not gated on show_contact? — looking up registrations on another org's bike is the point
          def show_other_registrations?
            @organization.enabled?("additional_registrations_information")
          end

          def other_registrations
            @other_registrations ||= (@bike.user.presence&.bikes || Bike.where(owner_email: @bike.owner_email))
              .where.not(id: @bike.id)
          end

          # Shared with the BikesTable so its column set/labels match the toggle panel
          def other_registrations_settings
            @other_registrations_settings ||= ComponentStructs::OrgSearchSettings.new(organization: @organization)
          end

          def other_registrations_count
            @other_registrations_count ||= other_registrations.count
          end

          def other_registrations? = other_registrations_count.positive?

          # The rest are reachable through the org search link below them
          def recent_other_registrations
            @recent_other_registrations ||= other_registrations.reorder(id: :desc).limit(OTHER_REGISTRATIONS_LIMIT)
          end

          def other_registrations_search_path
            organization_registrations_path(organization_id: @organization.to_param, search_email: @bike.owner_email)
          end

          def more_other_registrations?
            other_registrations_count > OTHER_REGISTRATIONS_LIMIT
          end
        end
      end
    end
  end
end
