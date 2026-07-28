# frozen_string_literal: true

module Register
  module Step2
    # Step 2 of the registration flow: the bike details form
    class Component < ApplicationComponent
      def initialize(b_param:, current_user: nil)
        @b_param = b_param
        @current_user = current_user
      end

      private

      def cycle_type
        @b_param.type
      end

      # A link is only outstanding for an anonymous registrant who hasn't clicked
      # it - a signed-in registration creates the bike straight from this step
      def awaiting_confirmation?
        @current_user.blank? && @b_param.partial_email_sent_to.present? && !@b_param.email_confirmed?
      end

      def organization
        return @organization if defined?(@organization)

        @organization = @b_param.creation_organization
      end

      # The additional registration fields, gated exactly as bikes/new gates them
      def show_extra_registration_number?
        helpers.include_field_reg_extra_registration_number?(organization, @current_user)
      end

      def show_organization_affiliation?
        helpers.include_field_reg_organization_affiliation?(organization, @current_user)
      end

      def show_student_id?
        helpers.include_field_reg_student_id?(organization, @current_user)
      end

      # Organizations can rename the fields they require
      def reg_label(field, default)
        helpers.registration_field_label(organization, field) || default
      end

      def show_reg_phone?
        helpers.include_field_reg_phone?(organization, @current_user)
      end

      # Mirrors bikes/new: stolen needs a contact number, impounded needs one
      # unless the finder has a confirmed phone, and an org can require it outright
      def phone_statuses
        @phone_statuses ||= if show_reg_phone?
          Bike.statuses
        else
          ["status_stolen"] + (@current_user&.phone_confirmed? ? [] : ["status_impounded"])
        end
      end

      # The inverse of phone: stolen and impounded hang their address off their own
      # record, so bikes/new only offers these fields for a plain registration
      # (BikeServices::Displayer.display_edit_address_fields?)
      def address_statuses
        @address_statuses ||= if BikeServices::Builder.include_address_record?(organization, @current_user)
          Bike.statuses - %w[status_stolen status_impounded unregistered_parking_notification]
        else
          []
        end
      end

      def show_address?
        address_statuses.include?(@b_param.status)
      end

      # form_with has no model here, so fields_for needs the record to render from
      def address_record
        @address_record ||= AddressRecord.new(@b_param.bike["address_record_attributes"]
          &.slice(*AddressRecord.permitted_params.map(&:to_s)) || {})
      end

      # An organization asking for more than a standard registration owns the section
      def contact_section_text
        return translation(".contact_info") unless organization_reg_fields?

        translation(".information_for_org", org_name: organization.short_name)
      end

      def organization_reg_fields?
        show_reg_phone? || show_extra_registration_number? ||
          show_organization_affiliation? || show_student_id? || address_statuses.any?
      end

      # bikes/new knows the status before rendering - here it's picked in this
      # form, so register--status-fields rechecks the list whenever it changes
      def show_phone?
        phone_statuses.include?(@b_param.status)
      end
    end
  end
end
