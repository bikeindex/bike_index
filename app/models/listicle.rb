class Listicle < ActiveRecord::Base
  belongs_to :blog
  mount_uploader :image, ListicleImageUploader

  default_scope { order("list_order ASC") }

  before_save :htmlize_content

  def htmlize_content
    self.body_html = Kramdown::Document.new(body).to_html if body.present?
    self.image_credits_html = Kramdown::Document.new(image_credits).to_html if image_credits.present?
  end
end
