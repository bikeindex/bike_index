# == Schema Information
#
# Table name: blogs
#
#  id               :integer          not null, primary key
#  body             :text
#  body_abbr        :text
#  canonical_url    :string
#  description_abbr :text
#  index_image      :string(255)
#  index_image_lg   :string(255)
#  is_info          :boolean          default(FALSE)
#  is_listicle      :boolean          default(FALSE), not null
#  kind             :integer          default("blog")
#  language         :integer          default("en"), not null
#  old_title_slug   :string(255)
#  published        :boolean
#  published_at     :datetime
#  secondary_title  :text
#  title            :text
#  title_slug       :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  index_image_id   :integer
#  user_id          :integer
#
class Blog < ApplicationRecord
  include ActionView::Helpers::TextHelper
  include Translatable
  include PgSearch::Model

  KIND_ENUM = {blog: 0, info: 1, listicle: 2}.freeze

  belongs_to :user
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :listicles, dependent: :destroy
  has_many :blog_content_tags, dependent: :destroy
  has_many :content_tags, through: :blog_content_tags
  accepts_nested_attributes_for :listicles, allow_destroy: true
  accepts_nested_attributes_for :blog_content_tags, allow_destroy: true

  validates_presence_of :title, :body, :user_id
  validates_uniqueness_of :title, message: "has already been taken. If you believe that this message is an error, contact us!"
  validates_uniqueness_of :title_slug, message: "somehow that overlaps with another title! Sorrys."

  before_save :set_calculated_attributes
  before_create :set_title_slug

  enum :kind, KIND_ENUM

  attr_accessor :post_date, :post_now, :update_title, :user_email, :timezone, :info_kind

  scope :published, -> { where(published: true) }
  default_scope { order("published_at desc") }

  pg_search_scope :text_search, against: {title: "A", body: "B"}

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.slugify_title(str)
    # Truncate, slugify, also - remove last char if a dash (slugify should take care of removing the dash now, but whatever)
    return nil unless str.present?
    Slugifyer.slugify(str)[0, 70].gsub(/-$/, "")
  end

  def self.integer_slug?(n)
    n.is_a?(Integer) || n.match(/\A\d+\z/).present?
  end

  def self.friendly_find(str)
    return nil unless str.present?
    return find_by_id(str) if integer_slug?(str)
    slug = slugify_title(str)
    find_by_title_slug(slug) || find_by_old_title_slug(slug) ||
      find_by_title_slug(str) || find_by_title(str) || find_by_secondary_title(str)
  end

  def self.theft_rings_id
    324
  end

  def self.why_donate_slug
    "end-2020-with-a-donation-to-bike-index"
  end

  def self.get_your_stolen_bike_back_slug
    "how-to-get-your-stolen-bike-back" # Also hard coded in routes
  end

  def self.membership_slug
    "bike-index-membership"
  end

  # matches ALL content tag ids
  def self.with_tag_ids(content_tag_ids)
    content_tag_ids = Array(content_tag_ids)
    joins(:blog_content_tags).where(blog_content_tags: {content_tag_id: content_tag_ids})
      .group("blogs.id").having("count(distinct blog_content_tags.id) = ?", content_tag_ids.count)
  end

  def self.with_any_of_tag_ids(content_tag_ids)
    content_tag_ids = Array(content_tag_ids)
    joins(:blog_content_tags).where(blog_content_tags: {content_tag_id: content_tag_ids})
  end

  # TODO: This is bad, but it's better than nothing so I'm going with it
  # NOTE: this is unscoped (so it removes the default scope)
  def self.ids_sorted_by_matching_tag_ids_count(content_tag_ids)
    grouped_ids = unscoped.joins(:blog_content_tags).where(blog_content_tags: {content_tag_id: content_tag_ids})
      .group("blog_content_tags.blog_id").count
    sorted_counted_ids = grouped_ids.to_a.sort { |a, b| b[1] <=> a[1] }
    sorted_counted_ids.map { |id, count| id }
  end

  def content_tag_names=(val)
    val = val.is_a?(Array) ? val : val.split(",")
    ctag_ids = val.map { |c| ContentTag.friendly_find_id(c) }.compact
    blog_content_tags.where.not(content_tag_id: ctag_ids).each { |c| c.destroy }
    blog_content_tag_ids = blog_content_tags.map(&:content_tag_id)
    (ctag_ids - blog_content_tag_ids).each { |c| blog_content_tags.build(content_tag_id: c) }
    blog_content_tags
  end

  def content_tag_names
    content_tags.name_ordered.pluck(:name)
  end

  # Returns 5 most related blogs in an array
  # TODO: Make this less of a shitshow
  def related_blogs
    blog_ids = self.class.ids_sorted_by_matching_tag_ids_count(content_tags.pluck(:id)) - [id]
    blogs = Blog.where(id: blog_ids[0..5]).published
    if blogs.count < 5
      blogs += Blog.where(id: blog_ids[6..15]).published
    end
    blogs[0..5].uniq
  end

  def to_param
    title_slug
  end

  def canonical_url?
    canonical_url.present?
  end

  def pretty_canonical
    return nil unless canonical_url?
    canonical_url.gsub(/https?:\/\//i, "").truncate(90)
  end

  def set_calculated_attributes
    self.published_at ||= Time.current # We need to have a published time...
    self.canonical_url = Urlifyer.urlify(canonical_url)
    set_published_at_and_published
    unless listicle?
      self.kind = (!InputNormalizer.boolean(info_kind)) ? "blog" : "info"
    end
    self.published_at = Time.current if info?
    update_title_save
    create_abbreviation
    set_index_image
  end

  def set_published_at_and_published
    if post_date.present?
      self.published_at = TimeParser.parse(post_date, timezone)
    end
    self.published_at = Time.current if post_now == "1"
    if user_email.present?
      u = User.fuzzy_email_find(user_email)
      self.user_id = u.id if u.present?
    end
  end

  def description
    return description_abbr if description_abbr.present?
    body_abbr
  end

  def feed_content
    if is_listicle
      listicles.collect { |l|
        ApplicationController.helpers.listicle_html(l)
      }.join.html_safe
    else
      Kramdown::Document.new(body).to_html
    end
  end

  def update_title_save
    return true unless InputNormalizer.boolean(update_title)
    self.old_title_slug = title_slug
    set_title_slug
  end

  def set_title_slug
    # We want to only set this once, and not change it, so that links don't break
    self.title_slug = self.class.slugify_title(title)
  end

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
      abbr = InputNormalizer.sanitize(body_html)
      # strip tags, then remove extra spaces
      abbr = abbr.tr("\n", " ").gsub(/\s+/, " ").strip if abbr.present?
      self.body_abbr = truncate(abbr, length: 200)
    end
    true
  end

  def set_index_image
    self.index_image_id = nil unless PublicImage.where(id: index_image_id).present?
    if index_image_id.present?
      if index_image_id == 0
        self.index_image = nil
      elsif is_listicle
        li = listicles.find(index_image_id)
      else
        pi = public_images.find(index_image_id)
      end
    elsif is_listicle && listicles.present? && listicles.first.image.present?
      li = listicles.first
      # self.index_image = listicles.first.image_url(:medium)
      self.index_image_id = li.id
    elsif public_images.present?
      pi = public_images.last
      self.index_image_id = public_images.last.id
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
end
