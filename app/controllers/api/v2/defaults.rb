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
          attr_reader :resource_owner

          def current_token
            @doorkeeper_access_token
          end

          def current_organization
            organization = Organization.friendly_find(params[:organization_slug])
            if organization.present? && current_user.authorized?(organization)
              organization
            end
          end

          def current_user
            return @resource_owner if @resource_owner&.confirmed?
            # If user isn't confirmed, raise error for us to manage
            raise ApiAuthorization::Errors::OAuthForbiddenError, "User is unconfirmed"
          end

          def current_scopes
            current_token&.scopes
          end
        end
      end
    end
  end
end
