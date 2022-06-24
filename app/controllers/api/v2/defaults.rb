module API
  module V2
    module Defaults
      extend ActiveSupport::Concern
      included do
        before do
          header["Access-Control-Allow-Origin"] = "*"
          header["Access-Control-Request-Method"] = "*"
        end

        helpers do
          def current_token
            ApiAuthorization::OAuth2.doorkeeper_access_token
          end

          def current_organization
            organization = Organization.friendly_find(params[:organization_slug])
            if organization.present? && current_user.authorized?(organization)
              organization
            end
          end

          # v3/me allows responses for unconfirmed users. All othere require a confirmed user
          def current_user(allow_unconfirmed = false)
            return nil unless resource_owner.present?
            return resource_owner if resource_owner.confirmed? || allow_unconfirmed
            # If user isn't confirmed, raise error for us to manage
            raise ApiAuthorization::Errors::OAuthForbiddenError, OpenStruct.new(description: "User is unconfirmed")
          end

          def current_scopes
            current_token&.scopes || []
          end

          private

          def resource_owner
            ApiAuthorization::OAuth2.resource_owner
          end
        end
      end
    end
  end
end
