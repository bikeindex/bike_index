# frozen_string_literal: true

module Register
  # A registration's photo is picked before there's an account to attach it to, so the b_param
  # token stands in for a session. Anyone can start a registration, so this is scoping and
  # attribution rather than a gate - the hourly per-IP throttle in rack_attack.rb is the teeth.
  # The organizations' embed forms upload here too, for the same reason.
  class DirectUploadsController < DirectUploads::BaseController
    prepend_before_action :require_registration

    private

    def require_registration
      head :forbidden if b_param.blank?
    end

    # An embed registration belongs to the organization handing out the form, not to whoever
    # fills it in, so find_token - which resumes a registration - won't hand it over. The
    # fallback is the lookup the embed page itself built the form from.
    def b_param
      return @b_param if defined?(@b_param)

      token = params[:b_param_token]
      @b_param = BikeServices::Register.find_token(user: current_user, params_token: token) ||
        BParam.find_from_token(token)
    end

    # A signed id is a bearer token, so without this any registration could claim any blob.
    # BParam#image_blob only hands back one stamped with its own id.
    def binx_data
      {"b_param_id" => b_param.id}
    end
  end
end
