# Regenerates deferred versions (see process_in_background). Looks the record up
# unscoped so a default_scope (e.g. PublicImage hiding is_private records) can't
# hide it and leave versions ungenerated.
#
# Uploaders that defer with Backgrounder::Delay (PublicImageUploader) also skip
# the original's top-level processors on the synchronous upload, so re-cache and
# re-store the original here — otherwise originals keep their EXIF orientation and
# metadata (incl. GPS). Re-caching reruns fix_exif_rotation + strip and rebuilds
# every version from the processed original in the one pass the versions need anyway.
class CarrierWaveProcessJob < ::CarrierWave::Workers::ProcessAsset
  sidekiq_options queue: "med_priority", backtrace: true, retry: 1

  private

  def recreate_asset_versions!(asset)
    Array(asset).each do |uploader|
      next if uploader.file.blank?
      uploader.cache!(uploader.file)
      uploader.store!
    end
  end

  def constantized_resource
    super.unscoped
  end
end
