# == Schema Information
#
# Table name: registration_sequence_pages
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  body                     :text
#  listing_order            :integer
#  subtitle                 :text
#  title                    :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  registration_sequence_id :bigint           not null
#
# Indexes
#
#  index_registration_sequence_pages_on_registration_sequence_id  (registration_sequence_id)
#
class RegistrationSequencePage < ApplicationRecord
  belongs_to :registration_sequence, inverse_of: :registration_sequence_pages

  has_one_attached :image

  # body is HTML from a Lexxy rich-text editor; sanitize to a safe subset on save
  before_validation :sanitize_body
  before_create :set_listing_order

  def image_url
    BlobUrl.for(image.blob) if image.attached?
  end

  private

  # Appended to the end; reordering is done by drag-and-drop on the sequence show page
  def set_listing_order
    self.listing_order ||= (registration_sequence&.registration_sequence_pages&.maximum(:listing_order) || -1) + 1
  end

  def sanitize_body
    self.body = ActionController::Base.helpers.sanitize(body) if body.present?
  end
end
