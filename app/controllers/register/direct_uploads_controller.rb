# frozen_string_literal: true

module Register
  # A registration's photo is picked before there's an account to attach it to, so the b_param
  # token stands in for a session. Anyone can start a registration, so this is scoping and
  # attribution rather than a gate - the hourly per-IP throttle in rack_attack.rb is the teeth.
  class DirectUploadsController < DirectUploads::BaseController
    before_action :require_registration

    private

    def require_registration
      return if BikeServices::Register.find_token(user: current_user, params_token: params[:b_param_token]).present?

      head :forbidden
    end
  end
end
