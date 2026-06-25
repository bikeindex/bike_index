# == Schema Information
#
# Table name: registration_sequence_pages
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  bullet_points            :text             default([]), is an Array
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

  before_validation :normalize_bullet_points

  def image_url
    BlobUrl.for(image.blob) if image.attached?
  end

  private

  def normalize_bullet_points
    self.bullet_points = Array(bullet_points).filter_map { |bullet| bullet.to_s.strip.presence }
  end
end
