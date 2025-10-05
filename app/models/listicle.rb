# == Schema Information
#
# Table name: listicles
#
#  id                 :integer          not null, primary key
#  body               :text
#  body_html          :text
#  crop_top_offset    :integer
#  image              :string(255)
#  image_credits      :text
#  image_credits_html :text
#  image_height       :integer
#  image_width        :integer
#  list_order         :integer
#  title              :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  blog_id            :integer
#
class Listicle < ApplicationRecord
  belongs_to :blog
  mount_uploader :image, ListicleImageUploader

  default_scope { order("list_order ASC") }

  before_save :htmlize_content

  def htmlize_content
    self.body_html = Kramdown::Document.new(body).to_html if body.present?
    self.image_credits_html = Kramdown::Document.new(image_credits).to_html if image_credits.present?
  end
end
