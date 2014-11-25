module Api
  module V2
    class UsersController < ApiV2Controller
      before_filter :authenticate_oauth_user!
      # doorkeeper_for :all

      def current
        result = {
          access_token: {
            application: doorkeeper_token.application.name,
            scope: oauth_scope,
          },
          id: @oauth_user.id.to_s
        }
        result[:user] = user_info if oauth_scope.include?('read_user')
        result[:bike_ids] = bike_ids if oauth_scope.include?('read_bikes')
        result[:memberships] = organization_memberships if oauth_scope.include?('read_organization_membership')
        respond_with result
      end

      private
      
      def user_info
        {
          username: @oauth_user.username,
          name: @oauth_user.name,
          email: @oauth_user.email, 
          twitter: (@oauth_user.twitter if @oauth_user.show_twitter),
          image: (@oauth_user.avatar_url if @oauth_user.show_bikes)
        }
      end
      
      def bike_ids
        @oauth_user.bikes
      end

      def organization_memberships
        return [] unless @oauth_user.memberships.any?
        @oauth_user.memberships.map{ |membership| 
          {
            organization_name: membership.organization.name,
            organization_slug: membership.organization.slug, 
            user_is_organization_admin: (true ? membership.role == 'admin' : false)
          }
        }
      end
     
    end
  end
end