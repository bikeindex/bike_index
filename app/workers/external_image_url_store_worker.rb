class ExternalImageUrlStoreWorker
  include Sidekiq::Worker
  sidekiq_options queue: "carrierwave", backtrace: true

  def perform(public_image_id)
    public_image = PublicImage.find(public_image_id)
    public_image.process_image_upload = true # Bypass carrierwave background, because we're already in background
    public_image
  end
end
