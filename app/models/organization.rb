class Organization < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  attr_accessible :available_invitation_count,
    :sent_invitation_count,
    :name,
    :short_name,
    :slug,
    :website,
    :show_on_map,
    :is_suspended,
    :org_type,
    :locations_attributes,
    :embedable_user_email,
    :auto_user_id,
    :api_access_approved,
    :access_token,
    :new_bike_notification,
    :lightspeed_cloud_api_key,
    :use_additional_registration_field,
    :wants_to_be_shown

  attr_accessor :embedable_user_email, :lightspeed_cloud_api_key
  acts_as_paranoid

  has_many :memberships, dependent: :destroy
  has_many :organization_deals, dependent: :destroy
  has_many :users, through: :memberships
  has_many :organization_invitations, dependent: :destroy
  belongs_to :auto_user, class_name: "User"

  has_many :bikes, foreign_key: 'creation_organization_id'

  has_many :locations, dependent: :destroy
  accepts_nested_attributes_for :locations, allow_destroy: true

  validates_presence_of :name

  validates_uniqueness_of :slug, message: "Slug error. You shouldn't see this - please contact admin@bikeindex.org"

  default_scope { order(:name) }

  scope :shown_on_map, -> { where(show_on_map: true, approved: true) }
  scope :shop, -> { where(org_type: 'shop') }
  scope :police, -> { where(org_type: 'police') }
  scope :advocacy, -> { where(org_type: 'advocacy') }
  scope :college, -> { where(org_type: 'college') }
  scope :manufacturer, -> { where(org_type: 'manufacturer') }

  def to_param
    slug
  end

  before_save :set_and_clean_attributes
  def set_and_clean_attributes
    self.name = strip_tags(name)
    self.name = "Stop messing about" unless name[/\d|\w/].present?
    self.website = Urlifyer.urlify(website) if website.present?
    self.short_name = name unless short_name.present?
    new_slug = Slugifyer.slugify(self.short_name).gsub(/\Aadmin/, '')
    # If the organization exists, don't invalidate because of it's own slug
    orgs = id.present? ? Organization.where('id != ?', id) : Organization.scoped
    while orgs.where(slug: new_slug).exists?
      i = i.present? ? i + 1 : 2
      new_slug = "#{new_slug}-#{i}"
    end
    self.slug = new_slug
  end

  before_save :set_auto_user
  def set_auto_user
    if self.embedable_user_email.present?
      u = User.fuzzy_email_find(embedable_user_email)
      self.auto_user_id = u.id if u.is_member_of?(self)
      if auto_user_id.blank? && embedable_user_email == ENV['AUTO_ORG_MEMBER']
        Membership.create(user_id: u.id, organization_id: id, role: 'member')
        self.auto_user_id = u.id
      end
    elsif self.auto_user_id.blank?
      return nil unless self.users.any?
      self.auto_user_id = self.users.first.id
    end
  end

  def allowed_show
    show_on_map && approved
  end

  before_save :set_locations_shown
  def set_locations_shown
    # Locations set themselves on save
    locations.each { |l| l.save unless l.shown == allowed_show }
  end

  def suspended?
    is_suspended?
  end

  before_save :truncate_short_name
  def truncate_short_name
    self.short_name = self.short_name.truncate(30)
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
