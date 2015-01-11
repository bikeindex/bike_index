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
    :is_listicle,
    :listicles_attributes,
    :user_email,
    :index_image_id,
    :index_image

  has_many :listicles, dependent: :destroy
  accepts_nested_attributes_for :listicles, allow_destroy: true

  attr_accessor :post_date, :post_now, :update_title, :user_email

  validates_presence_of :title, :body, :user_id
  validates_uniqueness_of :title, message: "has already been taken. If you believe that this message is an error, contact us!"
  validates_uniqueness_of :title_slug, message: "somehow that overlaps with another title! Sorrys."
  
  belongs_to :user
  has_many :public_images, as: :imageable, dependent: :destroy

  scope :published, where(published: true)
  scope :listicle_blogs, where(is_listicle: true)
  default_scope order("published_at desc")

  before_save :set_published_at_and_published
  def set_published_at_and_published
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
    body_abbr
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
    if description_abbr.present?
      self.body_abbr = description_abbr
    else
      if is_listicle && listicles.first.present?
        body_html = listicles.first.body_html
      else
        # Render markdown,
        markdown = Kramdown::Document.new(body)
        body_html = markdown.to_html
      end
      abbr = strip_tags(body_html)
      # strip tags, then remove extra spaces
      abbr = abbr.gsub(/\n/,' ').gsub(/\s+/, ' ').strip
      self.body_abbr = truncate(abbr, length: 200)
    end
    true
  end

  before_save :set_index_image
  def set_index_image
    if index_image_id.present?
      if index_image_id == 0
        self.index_image = nil
      elsif is_listicle
        li = listicles.find(index_image_id)
      else
        pi = public_images.find(index_image_id)
      end
    else
      if is_listicle && listicles.first.image.present?
        li = listicles.first
        # self.index_image = listicles.first.image_url(:medium)
        self.index_image_id = i.id
      elsif public_images.present?
        pi = public_images.last
        self.index_image_id = public_images.last.id
      end
    end
    if li.present?
      self.index_image = li.image_url(:medium) 
      self.index_image_lg = li.image_url(:large)
    elsif pi.present?
      self.index_image = pi.image_url(:small) 
      self.index_image_lg = pi.image_url(:large)
    end
    true
  end

  def to_param
    title_slug
  end

end
