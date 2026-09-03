# frozen_string_literal: true

# Shadows ActiveStorage's own direct uploads route (see config/routes.rb) so the stock
# controller isn't reachable. Signed-in surfaces upload here; the registration flow has its
# own endpoint because it runs before there's an account to check.
class DirectUploadsController < DirectUploads::BaseController
  prepend_before_action :require_current_user

  private

  def require_current_user
    head :forbidden if current_user.blank?
  end
end
