module API
  module V2
    class Me < API::Base
      include API::V2::Defaults
      resource :me, desc: "Operations about the current user" do
        helpers do 
          def user_info
            return {} unless current_scopes.include?('read_user')
            {
              user: {
                username: current_user.username,
                name: current_user.name,
                email: current_user.email, 
                twitter: (current_user.twitter if current_user.show_twitter),
                image: (current_user.avatar_url if current_user.show_bikes)
              }
            }
          end
          
          def bike_ids
            current_scopes.include?('read_bikes') ? { bike_ids: current_user.bike_ids } : {}
          end

          def serialized_membership(membership)
            {
              organization_name: membership.organization.name,
              organization_slug: membership.organization.slug, 
              organization_access_token: membership.organization.access_token,
              user_is_organization_admin: (true ? membership.role == 'admin' : false)
            }
          end

          def organization_memberships
            return {} unless current_scopes.include?('read_organization_membership')
            { memberships: current_user.memberships.map { |m| serialized_membership(m) } }
          end
        end

        desc "Current user's information in access token's scope<span class='accstr'>*</span>", {
          authorizations: { oauth2: [] },
          notes: <<-NOTE
            Current user is the owner of the `access_token` you use in the request. Depending on your scopes you will get different things back.
            You will always get the user's `id`
            For an array of the user's bike ids, you need `read_bikes` access
            For a hash of information about the user (including their email address), you need `read_user` access
            For an array of the organizations and/or shops they're a part of, `read_organization_membership` access

          NOTE
        }
        get '/' do
          { id: current_user.id.to_s }.merge(user_info).merge(bike_ids).merge(organization_memberships)
        end

        desc "Current user's bikes<span class='accstr'>*</span>", {
          authorizations: { oauth2: [{ scope: :read_bikes }] },
          notes: <<-NOTE
            This returns the current user's bikes, so long as the access_token has the `read_bikes` scope.
            This uses the bike list bike objects, which only contains the most important information.
            To get all possible information about a bike use `/bikes/{id}`

          NOTE
        }
        get '/bikes', each_serializer: BikeV2Serializer, root: 'bikes' do
          current_user.bikes
        end
      end
    end
  end
end