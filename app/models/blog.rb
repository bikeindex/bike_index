class Blog < ActiveRecord::Base
  include ActionView::Helpers::TextHelper
  attr_accessible :title,
    :body,
    :user_id,
    :post_date,
    :post_on,
    :tags,
    :published,
    :update_title
      
  attr_accessor :post_on, :update_title

  validates_presence_of :title, :body, :user_id
  validates_uniqueness_of :title, message: "has already been taken. If you believe that this message is an error, contact us!"
  validates_uniqueness_of :title_slug, message: "somehow that overlaps with another title! Sorrys."
  
  belongs_to :user
  has_many :public_images, as: :imageable, dependent: :destroy

  default_scope order("post_date desc")

  before_save :set_post_date
  def set_post_date
    if self.post_on
      self.post_date = DateTime.strptime("#{self.post_on} 06", "%m-%d-%Y %H")
    end
  end

  before_save :update_title_save
  def update_title_save
    set_title_slug if update_title.present? && update_title == "1"
  end

  before_create :set_title_slug
  def set_title_slug
    # We want to only set this once, and not change it, so that links don't break
    self.title_slug = truncate(Slugifyer.slugify(self.title), length: 50, :omission => '')
  end


  before_save :create_abbreviation
  def create_abbreviation
    # Remove newlines, remove square brackets, remove parentheses (generally link targets) and then remove extra spaces
    b_abbr = self.body.gsub(/\n/,' ').gsub(/[\[\]]/, '').gsub(/\![^)]*\)/, '').gsub(/\([^)]*\)/, '').gsub(/\<[^)]*\>/, '')
    # then remove extra spaces
    b_abbr = b_abbr.gsub(/\s+/, ' ').strip
    self.body_abbr = truncate(b_abbr, length: 200)
  end

  def to_param
    title_slug
  end

end
