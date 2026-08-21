# frozen_string_literal: true

module Registrations
  module Show
    module WrapperOrgAdmin
      class Component < ApplicationComponent
        include BikeHelper

        OTHER_REGISTRATIONS_LIMIT = 10
        # Registration fields shown with the owner rather than in registration info
        OWNER_ACCESS_REG_FIELDS = %w[reg_address reg_organization_affiliation reg_student_id].freeze

        # org_role is what this renders as — a superadmin can view any org either way
        def initialize(bike:, current_user:, organization:, org_role:, available_views: [], bike_sticker: nil,
          current_alerts: {}, display_dev_info: false)
          @bike = bike
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
          [bike_organization_note&.updated_at, organization_model_audit&.updated_at,
            other_registrations.maximum(:updated_at), other_registrations_count,
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

        def credibility_scorer
          @credibility_scorer ||= @bike.credibility_scorer
        end

        def credibility_score
          @credibility_score ||= credibility_scorer.score
        end

        # Matches the credibility_scorer_color used on bikes/show
        def credibility_color
          return "#dc3545" if credibility_score < 31
          return "#ffc107" if credibility_score < 70

          "#28a745"
        end

        def credibility_badges
          @credibility_badges ||= CredibilityScorer.permitted_badges_hash(credibility_scorer.badges)
        end

        def owner_phone
          @bike.phone if @bike.phoneable_by?(@current_user)
        end

        def current_ownership
          @current_ownership ||= @bike.current_ownership
        end

        def bike_stickers
          @bike_stickers ||= @bike.bike_stickers.reorder(claimed_at: :desc)
        end

        def sticker_link(bike_sticker)
          url = if bike_sticker.organization_id == @organization.id
            edit_organization_sticker_path(id: bike_sticker.code, organization_id: @organization.to_param)
          end

          render(Atom::Sticker::Component.new(bike_sticker:, url:))
        end

        def model_audit
          return @model_audit if defined?(@model_audit)

          @model_audit = @bike.model_audit
        end

        def organization_model_audit
          return @organization_model_audit if defined?(@organization_model_audit)

          @organization_model_audit = model_audit &&
            OrganizationModelAudit.find_by(organization_id: @organization.id, model_audit_id: @bike.model_audit_id)
        end

        # The org's additional registration fields as [label, value], blank ones dropped.
        # Sticker, phone, affiliation and student ID are shown elsewhere
        def org_registration_field_rows
          (@organization.additional_registration_fields - %w[reg_bike_sticker reg_phone] - OWNER_ACCESS_REG_FIELDS).filter_map do |reg_field|
            bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field)
            value = org_registration_field_value(bike_attr)
            next if value.blank?

            [org_registration_field_label(reg_field, bike_attr), value]
          end
        end

        # The owner & access card's rows — unlike the ones above, blank renders a "-"
        def owner_reg_field_rows
          (OWNER_ACCESS_REG_FIELDS & @organization.additional_registration_fields).map do |reg_field|
            bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field)
            [org_registration_field_label(reg_field, bike_attr), org_registration_field_value(bike_attr)]
          end
        end

        def org_registration_field_value(bike_attr)
          case bike_attr
          when "organization_affiliation" then @bike.organization_affiliation(@organization)&.humanize
          when "student_id" then @bike.student_id(@organization)
          when "address" then org_registration_address
          else @bike.send(bike_attr)
          end
        end

        def org_registration_field_label(reg_field, bike_attr)
          custom = @organization.registration_field_labels&.dig(reg_field)
          return Binxtils::InputNormalizer.sanitize(custom) if custom.present?

          bike_attr.humanize(keep_id_suffix: true)
        end

        def org_registration_address
          address = @bike.registration_address
          return if address.blank? || address == @organization.default_location&.address_hash_legacy

          [address["street"], address["city"], [address["state"], address["zipcode"]].compact_blank.join(" ")]
            .compact_blank.join(", ").presence
        end

        # Every row in that card is feature- or registration-gated
        def registration_information?
          organization_registered? || @organization.any_enabled?(%w[credibility_badges bike_stickers])
        end

        def show_notes?
          organization_registered? && @organization.enabled?("registration_notes")
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
          @other_registrations_settings ||=
            Org::Search::Settings::Component.new(organization: @organization, skip_search_and_filters: true)
        end

        def other_registrations_count
          @other_registrations_count ||= other_registrations.count
        end

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
