# frozen_string_literal: true

# ActiveStorage's own direct uploads controller accepts any content type, at any size, from
# anyone. Both endpoints below it hold uploads to what PublicImage can serve; each subclass
# adds who it will accept them from.
module DirectUploads
  class BaseController < ActiveStorage::DirectUploadsController
    private

    # The browser declares both, and the presigned URL is signed against what it declared -
    # so refusing here is what makes an oversized or non-image upload impossible rather than
    # merely unused.
    def require_permitted_file
      return if PublicImage::FILE_CONTENT_TYPES.include?(blob_args[:content_type]) &&
        blob_args[:byte_size].to_i.between?(1, PublicImageUploader::MAX_FILE_SIZE)

      head :unprocessable_entity
    end

    def current_user
      @current_user ||= AuthRestriction.user_from(request)
    end
  end
end
