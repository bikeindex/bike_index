# == Schema Information
#
# Table name: registration_sequence_pages
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  listing_order            :integer
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
  has_rich_text :content

  def image_url
    BlobUrl.for(image.blob) if image.attached?
  end
end
