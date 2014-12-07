module API
  module V2
    class Users < API::V2::Root
      include API::V2::Defaults

      resource :users do
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
            current_user.bikes
          end

          def organization_memberships
            return [] unless current_user.memberships.any?
            current_user.memberships.map{ |membership| 
              {
                organization_name: membership.organization.name,
                organization_slug: membership.organization.slug, 
                organization_access_token: membership.organization.access_token,
                user_is_organization_admin: (true ? membership.role == 'admin' : false)
              }
            }
          end
        end

        desc "Current user's information allowed in the current access token scope", {
          notes: <<-NOTE
            Depending on your scopes you will get different things back.
            For an array of the user's bike ids, you need `read_bikes` access
            For a hash of information about the user (including their email address), you need `read_user` access
            For an array of the organizations and/or shops they're a part of, `read_organization_membership` access

          NOTE
        }

        # This is the method that is called once authentication passes, to get info
        # about the user.
        get '/current' do
          result = {
            id: current_user.id.to_s
          }
          result[:user] = user_info if current_scopes.include?('read_user')
          result[:bike_ids] = bike_ids if current_scopes.include?('read_bikes')
          result[:memberships] = organization_memberships if current_scopes.include?('read_organization_membership')
          result
        end
      
      end
    end
  end
end