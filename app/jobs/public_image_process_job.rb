# PublicImage's default_scope hides is_private records, so the backgrounder's
# default PublicImage.find(id) lookup raises RecordNotFound for private images
# and their versions never get generated. Look the record up unscoped.
class PublicImageProcessJob < ::CarrierWave::Workers::ProcessAsset
  sidekiq_options queue: "med_priority", retry: 2

  private

  def constantized_resource
    super.unscoped
  end
end
