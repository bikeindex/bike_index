module Oauth
  class AuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
    include ControllerHelpers
    before_action :authenticate_user
    skip_before_action :verify_authenticity_token, only: [:destroy] # Because it was causing issues, and we don't need it here
  end
end
