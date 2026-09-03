# frozen_string_literal: true

# ActiveStorage's own direct uploads controller accepts any content type, at any size, from
# anyone. Both endpoints below it hold uploads to what PublicImage can serve; each subclass
# adds who it will accept them from.
module DirectUploads
  class BaseController < ActiveStorage::DirectUploadsController
    # Subclasses prepend their authorization, so it runs before this - binx_data can rely
    # on whoever is asking having been resolved
    before_action :require_permitted_file

    # create_before_direct_upload! takes explicit keywords, so binx_data can't ride along in
    # blob_args. Otherwise the same as ActiveStorage's.
    def create
      blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
      blob.update!(binx_data:) if binx_data.present?
      render json: direct_upload_json(blob)
    end

    private

    # Refuses on what the browser declares, before any bytes are written - the presigned URL is
    # signed against these values, so S3 holds the upload to the size it caps. PublicImage's
    # validation is what checks the stored bytes, once there are some to check.
    def require_permitted_file
      return if PublicImage.file_permitted?(**blob_args.slice(:content_type, :byte_size))

      head :unprocessable_entity
    end

    # ActiveStorage permits the client's metadata. Nothing reads it - analyze writes the real
    # values and our own keys live in binx_data - so drop it rather than persist client input.
    def blob_args
      super.merge(metadata: {})
    end

    def binx_data
      {}
    end

    def current_user
      @current_user ||= AuthRestriction.user_from(request)
    end
  end
end
