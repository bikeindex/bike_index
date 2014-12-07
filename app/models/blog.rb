class Blog < ActiveRecord::Base
  include ActionView::Helpers::TextHelper
  attr_accessible :title,
    :body,
    :user_id,
    :published_at,
    :post_date,
    :post_now,
    :tags,
    :published,
    :old_title_slug,
    :description_abbr,
    :update_title,
    :user_email
      
  attr_accessor :post_date, :post_now, :update_title, :user_email

  validates_presence_of :title, :body, :user_id
  validates_uniqueness_of :title, message: "has already been taken. If you believe that this message is an error, contact us!"
  validates_uniqueness_of :title_slug, message: "somehow that overlaps with another title! Sorrys."
  
  belongs_to :user
  has_many :public_images, as: :imageable, dependent: :destroy

  scope :published, where(published: true)
  default_scope order("published_at desc")

  before_save :set_published_at_and_publishe
  def set_published_at_and_publishe
    if self.post_date.present?
      self.published_at = DateTime.strptime("#{self.post_date} 06", "%m-%d-%Y %H")
    end
    self.published_at = Time.now if self.post_now == '1'
    if self.user_email.present?
      u = User.fuzzy_email_find(user_email)
      self.user_id = u.id if u.present?
    end
  end

  def description
    return description_abbr if description_abbr.present?
    self.body_abbr
  end

  before_save :update_title_save
  def update_title_save
    return true unless update_title.present?
    return true if update_title == false || update_title == '0'
    self.old_title_slug = self.title_slug
    set_title_slug
  end

  before_create :set_title_slug
  def set_title_slug
    # We want to only set this once, and not change it, so that links don't break
    t_slug = truncate(Slugifyer.slugify(self.title), length: 70, omission: '')
    # also - remove last char if a dash
    self.title_slug = t_slug.gsub(/\-$/, '')
  end


  before_save :create_abbreviation
  def create_abbreviation
    # Render markdown,
    markdown = Kramdown::Document.new(body)
    abbr = strip_tags(markdown.to_html)
    # strip tags, then remove extra spaces
    abbr = abbr.gsub(/\n/,' ').gsub(/\s+/, ' ').strip
    self.body_abbr = truncate(abbr, length: 200)
  end

  def to_param
    title_slug
  end

end
