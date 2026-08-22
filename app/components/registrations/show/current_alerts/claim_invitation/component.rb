# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module ClaimInvitation
        # Invites the registration's owner to claim it — either signed in as someone it's
        # claimable by, or arriving from the claim link in their registration email
        class Component < ApplicationComponent
          MODAL_ID = "claim-invitation-modal"

          def initialize(bike:, current_user: nil, claim_message: nil, variant: :modal)
            @bike = bike
            @current_user = current_user
            @claim_message = claim_message
            @variant = variant
          end

          # Parking notification registrations have no owner to invite
          def render?
            return false if ownership.blank? || @bike.creator_unregistered_parking_notification?

            claimable? || @claim_message.present?
          end

          private

          def signed_in? = @current_user.present?

          # Follows claim_path — only someone without an account is being asked to make one
          def claim_button_text
            return translation(".claim_bike_type", bike_type: @bike.type) if signed_in?

            translation(".sign_up_to_claim")
          end

          # Memoized — hits UserEmail, and render? and the template both ask
          def claimable?
            return @claimable if defined?(@claimable)

            @claimable = @bike.claimable_by?(@current_user)
          end

          def ownership
            @bike.current_ownership
          end

          # ownerships#show claims it, or says whose it is. Signed out, they sign up
          # against the ownership's email and come back
          def claim_path
            return ownership_path(ownership) if signed_in?

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
            return unless OrgServices::Displayer.avatar?(organization)

            image_tag(organization.avatar.url(:medium), alt: organization.name, class: "tw:h-10 tw:w-10 tw:rounded-full")
          end

          # Parens included, so they're sized with the link rather than the sentence
          def read_more_link
            link = link_to(translation(".read_more"), about_path, target: "_blank", rel: "noopener", class: "twlink-underlined")
            tag.span(safe_join(["(", link, ")"]), class: "tw:text-sm")
          end
        end
      end
    end
  end
end
