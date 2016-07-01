class Listicle < ActiveRecord::Base
  def self.old_attr_accessible
    %w(list_order body blog_id image title body_html image_width image_height
       image_credits image_credits_html crop_top_offset).map(&:to_sym).freeze
  end

  belongs_to :blog 
  mount_uploader :image, ListicleImageUploader
  process_in_background :image, CarrierWaveProcessWorker

  default_scope { order('list_order ASC') }

  before_save :htmlize_content
  def htmlize_content
    self.body_html = Kramdown::Document.new(body).to_html if body.present?
    self.image_credits_html = Kramdown::Document.new(image_credits).to_html if image_credits.present?
  end

end
