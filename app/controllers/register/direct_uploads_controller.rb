# frozen_string_literal: true

module Register
  # A registration's photo is picked before there's an account to attach it to, so the b_param
  # token stands in for a session. Anyone can start a registration, so this is scoping and
  # attribution rather than a gate - the hourly per-IP throttle in rack_attack.rb is the teeth.
  class DirectUploadsController < DirectUploads::BaseController
    prepend_before_action :require_registration

    private

    def require_registration
      head :forbidden if b_param.blank?
    end

    def b_param
      return @b_param if defined?(@b_param)

      @b_param = BikeServices::Register.find_token(user: current_user, params_token: params[:b_param_token])
    end

    # A signed id is a bearer token, so without this any registration could claim any blob.
    # BParam#image_blob only hands back one stamped with its own id.
    def blob_metadata
      {"b_param_id" => b_param.id}
    end
  end
end
