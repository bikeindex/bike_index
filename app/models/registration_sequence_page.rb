# == Schema Information
#
# Table name: registration_sequence_pages
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  body                     :text
#  body_html                :text
#  listing_order            :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  registration_sequence_id :bigint           not null
#
# A single page in a RegistrationSequence: one image plus a Markdown body (rendered to body_html).
class RegistrationSequencePage < ApplicationRecord
  belongs_to :registration_sequence, inverse_of: :pages

  has_one_attached :image

  before_save :htmlize_body

  def image_url
    BlobUrl.for(image.blob) if image.attached?
  end

  private

  def htmlize_body
    self.body_html = body.present? ? Kramdown::Document.new(body).to_html : nil
  end
end
