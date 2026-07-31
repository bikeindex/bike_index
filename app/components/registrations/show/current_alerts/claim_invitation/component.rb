# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module ClaimInvitation
        # Invites the registration's owner to claim it — either because they're signed
        # in as someone it's claimable by, or because they followed the claim link from
        # their registration email (claim_message, so they may still be signed out)
        class Component < ApplicationComponent
          MODAL_ID = "claim-invitation-modal"

          def initialize(bike:, current_user: nil, claim_message: nil)
            @bike = bike
            @current_user = current_user
            @claim_message = claim_message
          end

          # Parking notification registrations have no owner to invite
          def render?
            return false if ownership.blank? || @bike.creator_unregistered_parking_notification?

            claimable? || @claim_message.present?
          end

          # Shown by TokenAlert, which links to this dialog rather than repeating it
          def alert_text = translation(".your_bike", bike_type: @bike.type)

          def alert_button_text = claim_button_text

          private

          # Follows claim_path: a signed-in claimant claims outright, anyone else is
          # being sent to sign up first
          def claim_button_text
            return translation(".claim_bike_type", bike_type: @bike.type) if claimable?

            translation(".sign_up_to_claim")
          end

          # Memoized: this hits UserEmail, and render? plus the template and claim_path
          # all ask
          def claimable?
            return @claimable if defined?(@claimable)

            @claimable = @bike.claimable_by?(@current_user)
          end

          def ownership
            @bike.current_ownership
          end

          # A signed-in claimant claims in one click; anyone else signs up against the
          # ownership's email and returns to the claim link
          def claim_path
            return ownership_path(ownership) if claimable?

            new_user_path(email: ownership.owner_email,
              return_to: registration_path(@bike, t: ownership.token, email: ownership.owner_email))
          end

          def registered_by
            organization = ownership.organization
            return organization.name if organization.present?

            ownership.creator&.name.presence || EmailNormalizer.obfuscate(ownership.creator&.email)
          end

          def organization_avatar
            organization = ownership.organization
            return unless OrganizationDisplayer.avatar?(organization)

            image_tag(organization.avatar.url(:medium), alt: organization.name, class: "tw:h-10 tw:w-10 tw:rounded-full")
          end

          def read_more_link
            link_to(translation(".read_more"), about_path, target: "_blank", rel: "noopener", class: "twlink")
          end
        end
      end
    end
  end
end
