# frozen_string_literal: true

# Shadows ActiveStorage's own direct uploads route (see config/routes.rb), which hands anyone
# who asks a presigned URL to write anything, at any size, into our bucket. Every direct upload
# in the app is a registration photo, so this holds them to that.
class DirectUploadsController < ActiveStorage::DirectUploadsController
  before_action :require_registration, :require_permitted_file

  private

  # Ties the upload to a registration in progress. Anyone can start one, so this is scoping
  # and attribution rather than a gate - the throttles in rack_attack.rb are the teeth.
  def require_registration
    return if BParam.find_for_token(params[:b_param_token], user_id: current_user&.id).present?

    head :forbidden
  end

  # The browser declares both, and the presigned URL is signed against what it declared -
  # so refusing here is what keeps a 5GB zip from being uploadable at all.
  def require_permitted_file
    return if PublicImage::FILE_CONTENT_TYPES.include?(blob_args[:content_type]) &&
      blob_args[:byte_size].to_i.between?(1, PublicImageUploader::MAX_FILE_SIZE)

    head :unprocessable_entity
  end

  def current_user
    @current_user ||= AuthRestriction.user_from(request)
  end
end
