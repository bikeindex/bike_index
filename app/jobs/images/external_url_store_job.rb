class Images::ExternalUrlStoreJob < ApplicationJob
  sidekiq_options queue: "med_priority"

  def perform(public_image_id)
    public_image = PublicImage.unscoped.find_by(id: public_image_id)
    return if public_image.blank? || public_image.image.present? || public_image.external_image_url.blank?

    public_image.update(remote_image_url: public_image.external_image_url)
  end
end
