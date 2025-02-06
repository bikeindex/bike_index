module API
  module V2
    class Users < API::Base
      include API::V2::Defaults

      resource :users, desc: "Deprecated" do
        helpers do
          def user_info
            {
              username: current_user.username,
              name: current_user.name,
              email: current_user.email,
              twitter: (current_user.twitter if current_user.show_twitter),
              image: (current_user.avatar_url if current_user.show_bikes)
            }
          end

          def bike_ids
            current_user.bike_ids
          end

          def organization_organization_roles
            return [] unless current_user.organization_roles.any?
            current_user.organization_roles.map { |membership|
              {
                organization_name: membership.organization.name,
                organization_slug: membership.organization.slug,
                organization_access_token: membership.organization.access_token,
                user_is_organization_admin: membership.role == "admin"
              }
            }
          end
        end

        desc "Current user's information in access token's scope", {
          authorizations: {oauth2: {}},
          notes: <<-NOTE
            Current user is the owner of the `access_token` you use in the request. Depending on your scopes you will get different things back.
            You will always get the user's `id`
            For an array of the user's bike ids, you need `read_bikes` access
            For a hash of information about the user (including their email address), you need `read_user` access
            For an array of the organizations and/or shops they're a part of, `read_organization_membership` access

          NOTE
        }
        get "/current", hidden: true do
          result = {
            id: current_user.id.to_s
          }
          result[:user] = user_info if current_scopes.include?("read_user")
          result[:bike_ids] = bike_ids if current_scopes.include?("read_bikes")
          result[:organization_roles] = organization_organization_roles if current_scopes.include?("read_organization_membership")
          result
        end

        desc "Current user's bikes", {
          authorizations: {oauth2: {scope: :read_bikes}},
          notes: <<-NOTE
            This returns the current user's bikes, so long as the access_token has the `read_bikes` scope.
            This uses the bike list bike objects, which only contains the most important information.
            To get all possible information about a bike use `/bikes/{id}`

          NOTE
        }
        get "/current/bikes", hidden: true do
          ActiveModel::ArraySerializer.new(current_user.bikes,
            each_serializer: BikeV2Serializer,
            root: "bikes").as_json
        end
      end
    end
  end
end
