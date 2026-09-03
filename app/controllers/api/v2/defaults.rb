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
            env["doorkeeper_access_token"]
          end

          def current_organization
            return @current_organization if defined?(@current_organization)

            organization = Organization.friendly_find(params[:organization_slug])
            if organization.present? && current_user.authorized?(organization)
              @current_organization = organization
            end
          end

          def current_user
            return nil unless resource_owner.present?
            return resource_owner if resource_owner.confirmed? || permit_unconfirmed_user?

            # If user isn't confirmed, raise error for us to manage
            error!("User is unconfirmed", 403)
          end

          def current_scopes
            current_token&.scopes || []
          end

          def permanent_token?
            current_user&.id == ENV["V2_ACCESSOR_ID"].to_i
          end

          # client_credentials flow. See #2282
          def doorkeeper_authorized_no_user?
            env["doorkeeper_authorized_no_user"]
          end

          def doorkeeper_application
            current_token&.application
          end

          private

          # overridden in v3/me. All others require a confirmed user
          def permit_unconfirmed_user?
            false
          end

          def resource_owner
            env["resource_owner"]
          end
        end
      end
    end
  end
end
