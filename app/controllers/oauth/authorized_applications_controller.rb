module Oauth
  class AuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
    include ControllerHelpers
    before_filter :authenticate_user
  end
end
