class Organization < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper

  attr_accessor :embedable_user_email, :lightspeed_cloud_api_key
  acts_as_paranoid

  mount_uploader :avatar, AvatarUploader

  has_many :memberships, dependent: :destroy
  has_many :organization_deals, dependent: :destroy
  has_many :users, through: :memberships
  has_many :organization_invitations, dependent: :destroy
  belongs_to :auto_user, class_name: 'User'

  has_many :bikes, foreign_key: 'creation_organization_id'

  has_many :locations, dependent: :destroy
  accepts_nested_attributes_for :locations, allow_destroy: true

  # For organization landing
  has_many :public_images, as: :imageable, dependent: :destroy

  validates_presence_of :name

  validates_uniqueness_of :slug, message: "Slug error. You shouldn't see this - please contact admin@bikeindex.org"

  default_scope { order(:name) }

  scope :shown_on_map, -> { where(show_on_map: true, approved: true) }
  scope :shop, -> { where(org_type: 'shop') }
  scope :police, -> { where(org_type: 'police') }
  scope :advocacy, -> { where(org_type: 'advocacy') }
  scope :college, -> { where(org_type: 'college') }
  scope :manufacturer, -> { where(org_type: 'manufacturer') }
  scope :paid, -> { where(is_paid: true) }

  def self.friendly_find(n)
    return nil unless n.present?
    integer_slug?(n) ? find(n) : find_by_slug(Slugifyer.slugify(n))
  end

  def self.integer_slug?(n)
    n.is_a?(Integer) || n.match(/\A\d*\z/).present?
  end

  def to_param
    slug
  end

  before_save :set_and_clean_attributes
  def set_and_clean_attributes
    self.name = strip_tags(name)
    self.name = "Stop messing about" unless name[/\d|\w/].present?
    self.website = Urlifyer.urlify(website) if website.present?
    self.short_name = (short_name || name).truncate(30)
    new_slug = Slugifyer.slugify(self.short_name).gsub(/\Aadmin/, '')
    # If the organization exists, don't invalidate because of it's own slug
    orgs = id.present? ? Organization.where('id != ?', id) : Organization.all
    while orgs.where(slug: new_slug).exists?
      i = i.present? ? i + 1 : 2
      new_slug = "#{new_slug}-#{i}"
    end
    self.slug = new_slug
  end

  def ensure_auto_user
    return true if auto_user.present?
    self.embedable_user_email = users.first && users.first.email || ENV['AUTO_ORG_MEMBER']
    save
  end

  before_save :set_auto_user
  def set_auto_user
    if embedable_user_email.present?
      u = User.fuzzy_email_find(embedable_user_email)
      self.auto_user_id = u.id if u && u.is_member_of?(self)
      if auto_user_id.blank? && embedable_user_email == ENV['AUTO_ORG_MEMBER']
        Membership.create(user_id: u.id, organization_id: id, role: 'member')
        self.auto_user_id = u.id
      end
    elsif auto_user_id.blank?
      return nil unless users.any?
      self.auto_user_id = users.first.id
    end
  end

  def allowed_show
    show_on_map && approved
  end

  def display_avatar
    is_paid && avatar.present?
  end

  before_save :set_locations_shown
  def set_locations_shown
    # Locations set themselves on save
    locations.each { |l| l.save unless l.shown == allowed_show }
  end

  def suspended?
    is_suspended?
  end

  before_save :set_access_token
  def set_access_token
    generate_access_token unless self.access_token.present?
  end

  after_save :clear_map_cache
  def clear_map_cache
    Rails.cache.delete "views/info_where_page"
  end

  def generate_access_token
    begin
      self.access_token = SecureRandom.hex
    end while self.class.exists?(access_token: access_token)
  end

end
