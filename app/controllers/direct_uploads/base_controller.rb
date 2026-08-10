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

    # The registration an upload is scoped to. Only the subclasses a token authorizes have one.
    def b_param
    end

    # Prepended by those subclasses - a token that names no registration authorizes nothing
    def require_registration
      head :forbidden if b_param.blank?
    end

    # A signed id is a bearer token, so without this any registration could claim any blob.
    # BParam#image_blob only hands back one stamped with its own id.
    def binx_data
      b_param.present? ? {"b_param_id" => b_param.id} : {}
    end

    def current_user
      @current_user ||= AuthRestriction.user_from(request)
    end
  end
end
