# frozen_string_literal: true

module Emails
  module FinishedRegistration
    class Component < ApplicationComponent
      def self.tempo_snippet_for_ownership?(ownership)
        ownership.status_with_owner? &&
          ownership.new_registration? &&
          ownership.organization_id.blank?
      end

      def initialize(ownership:, bike: nil, email_preview: false)
        @ownership = ownership
        @bike = bike
        @email_preview = email_preview
      end

      def email_sent_at
        @ownership&.created_at if @ownership&.persisted?
      end

      private

      def claim_message?
        @ownership.claim_message.present?
      end

      def claimed?
        @ownership.claimed?
      end

      def show_after_welcome_snippet?
        organization_snippet_body("after_welcome").present?
      end

      def show_security_snippet?
        organization_snippet_body("security").present?
      end

      def show_default_security_section?
        !show_security_snippet? && !bike.status_impounded?
      end

      def show_whats_next_section?
        claimed? && !claim_message? && !bike.status_stolen_or_impounded?
      end

      def show_template_promo_section?
        !bike.status_impounded?
      end

      def intro_heading
        return translation("thanks_for_adding_this_bike_type_you_found", bike_type: bike.type) if bike.status_impounded?
        return translation("bike_type_thieves_are_jerks", bike_type: bike.type) if bike.status_stolen?
        return translation("claim_your_bike_type", bike_type: bike.type) if claim_message?

        if organization.present?
          translation("bike_register_with_bike_index_and_org", bike_type: bike.type, org_name: organization.short_name)
        else
          translation("bike_register_with_bike_index", bike_type: bike.type)
        end
      end

      def intro_body
        return translation("were_sorry_your_bike_type_was_stolen", bike_type: bike.type) if bike.status_stolen?
        return if bike.status_impounded?
        return translation("registration_complete_message") if claimed?

        translation("registration_confirm_message")
      end

      def detail_message
        return if claim_message?

        if registered_by_owner?
          translation("you_added_a_bike_type_on_bike_index", bike_type: bike_type_for_message)
        elsif new_bike?
          "<strong>#{org_name}</strong> #{translation("org_added_a_bike", bike_type: bike_type_for_message)}".html_safe
        else
          "<strong>#{org_name}</strong> #{translation("org_sent_a_bike", bike_type: bike_type_for_message)}".html_safe
        end
      end

      def claim_cta_text
        return translation("claim_the_bike_type", bike_type: bike.type) if registered_by_owner?

        translation("confirm_this_bike_type", bike_type: bike.type)
      end

      def template_asset_url(name)
        "https://files.bikeindex.org/email_assets/#{name}"
      end

      def organization_snippet_body(kind)
        @organization_snippet_bodies ||= Hash.new { |h, k| h[k] = organization&.mail_snippet_body(k, time: email_sent_at) }
        @organization_snippet_bodies[kind]
      end

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

      def donation_message?
        bike.status_stolen? && !(organization && !organization.paid?)
      end

      def registered_by_owner?
        @ownership.user.present? && bike.creator_id == @ownership.user_id
      end

      def render_tempo_snippet?
        self.class.tempo_snippet_for_ownership?(@ownership) && tempo_snippet&.is_enabled
      end

      def tempo_snippet
        @tempo_snippet ||= MailSnippet.tempo.order(:id).last
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
          OrganizedServices::EmailPreview::TOKEN_PATH
        else
          bike_url(bike, t: @ownership.token, email:)
        end
      end

      def recovery_url
        if @email_preview
          OrganizedServices::EmailPreview::TOKEN_PATH
        else
          edit_bike_recovery_url(bike_id: bike.id, token: bike.fetch_current_stolen_record.find_or_create_recovery_link_token)
        end
      end

      def show_organization_stolen_message?
        OrganizationStolenMessage.shown_to?(bike.current_stolen_record)
      end
    end
  end
end
