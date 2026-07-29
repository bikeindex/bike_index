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

    # Both values are the browser's claim, and the presigned URL is signed against them - so
    # this caps how much can be written and keeps obvious junk out, but it can't verify the
    # bytes. Nothing does yet; the model validation reads the same declared values.
    def require_permitted_file
      return if PublicImage.file_permitted?(**blob_args.slice(:content_type, :byte_size))

      head :unprocessable_entity
    end

    # Drops whatever metadata was posted rather than merging it. ActiveStorage permits the
    # client's, and the keys mean something here - "processed" would skip the job that strips
    # EXIF, leaving the GPS coordinates of wherever the bike was photographed in the original.
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
