# == Schema Information
#
# Table name: registration_sequence_pages
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  bullet_points            :text             default([]), is an Array
#  bullet_points_html       :text             default([]), is an Array
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
  before_save :htmlize_bullet_points

  def image_url
    BlobUrl.for(image.blob) if image.attached?
  end

  private

  def normalize_bullet_points
    self.bullet_points = Array(bullet_points).filter_map { |bullet| bullet.to_s.strip.presence }
  end

  # Render Markdown once on save so the preview doesn't re-parse on every view
  def htmlize_bullet_points
    self.bullet_points_html = bullet_points.map { |bullet| Markdown.to_safe_html(bullet) }
  end
end
