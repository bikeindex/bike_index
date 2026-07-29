# frozen_string_literal: true

# Shadows ActiveStorage's own direct uploads route (see config/routes.rb), whose controller
# accepts any content type, at any size, from anyone.
class DirectUploadsController < ActiveStorage::DirectUploadsController
  before_action :require_current_user, :require_permitted_file

  private

  def require_current_user
    head :forbidden if current_user.blank?
  end

  # The browser declares both, and the presigned URL is signed against what it declared - so
  # refusing here is what makes an oversized or non-image upload impossible rather than merely
  # unused.
  def require_permitted_file
    return if PublicImage::FILE_CONTENT_TYPES.include?(blob_args[:content_type]) &&
      blob_args[:byte_size].to_i.between?(1, PublicImageUploader::MAX_FILE_SIZE)

    head :unprocessable_entity
  end

  def current_user
    @current_user ||= AuthRestriction.user_from(request)
  end
end
