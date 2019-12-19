module Oauth
  class AuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
    include ControllerHelpers
    before_action :authenticate_user
  end
end
