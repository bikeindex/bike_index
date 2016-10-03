module oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ControllerHelpers
    before_filter :authenticate_user
  end
end