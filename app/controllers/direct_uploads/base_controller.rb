# frozen_string_literal: true

# ActiveStorage's own direct uploads controller accepts any content type, at any size, from
# anyone. Both endpoints below it hold uploads to what PublicImage can serve; each subclass
# adds who it will accept them from.
module DirectUploads
  class BaseController < ActiveStorage::DirectUploadsController
    before_action :require_permitted_file

    private

    # Both values are the browser's claim, and the presigned URL is signed against them - so
    # this caps how much can be written and keeps obvious junk out, but it can't verify the
    # bytes. Nothing does yet; the model validation reads the same declared values.
    def require_permitted_file
      return if PublicImage.file_permitted?(**blob_args.slice(:content_type, :byte_size))

      head :unprocessable_entity
    end

    def current_user
      @current_user ||= AuthRestriction.user_from(request)
    end
  end
end
