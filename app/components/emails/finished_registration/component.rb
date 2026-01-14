# frozen_string_literal: true

module Emails::FinishedRegistration
  class Component < ApplicationComponent
    def initialize(ownership:, bike: nil, email_preview: false)
      @ownership = ownership
      @bike = bike
      @email_preview = email_preview
    end

    private

    def bike
      @bike ||= Bike.unscoped.find(@ownership.bike_id)
    end

    def user
      @ownership.owner
    end

    def organization
      @ownership.organization
    end

    def creation_org
      bike.creation_organization
    end

    def email
      @ownership.owner_email
    end

    def new_bike?
      @ownership.new_registration?
    end

    def new_user?
      User.fuzzy_email_find(@ownership.owner_email).present?
    end

    def donation_message?
      bike.status_stolen? && !(organization && !organization.paid?)
    end

    def registered_by_owner?
      @ownership.user.present? && bike.creator_id == @ownership.user_id
    end

    def org_name
      creation_org&.name || @ownership&.creator&.display_name
    end

    def bike_type_for_message
      if bike.status_impounded?
        translation("recovered_bike_type", bike_type: bike.type)
      elsif bike.status_stolen?
        translation("stolen_bike_type", bike_type: bike.type)
      else
        bike.type
      end
    end

    def bike_url_with_token
      if @email_preview
        "/404"
      else
        helpers.bike_url(bike, t: @ownership.token, email:)
      end
    end

    def recovery_url
      if @email_preview
        "/404"
      else
        helpers.edit_bike_recovery_url(bike_id: bike.id, token: bike.fetch_current_stolen_record.find_or_create_recovery_link_token)
      end
    end

    def show_organization_stolen_message?
      OrganizationStolenMessage.shown_to?(bike.current_stolen_record)
    end
  end
end
