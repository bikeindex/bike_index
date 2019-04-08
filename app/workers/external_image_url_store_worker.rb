class ExternalImageUrlStoreWorker
  include Sidekiq::Worker
  sidekiq_options queue: "carrierwave", backtrace: true

  def perform(public_image_id)
    public_image = PublicImage.find(public_image_id)
    return true if public_image.image.present? || public_image.external_image_url.blank?
    public_image.update_attributes(remote_image_url: public_image.external_image_url)
  end
end
