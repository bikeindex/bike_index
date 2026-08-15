# frozen_string_literal: true

module PageBlock
  module Skeletons
    module OauthApplications
      # The shell for managing your own OAuth applications - the authorization prompt
      # uses the doorkeeper layout instead, which has no site chrome
      class Component < ApplicationComponent
        def initialize(oauth_application:, current_user:, action_name:)
          @oauth_application = oauth_application
          @current_user = current_user
          @action_name = action_name
        end
      end
    end
  end
end
