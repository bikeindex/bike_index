class Organization < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  KIND_ENUM = {
    bike_shop: 0,
    bike_advocacy: 1,
    law_enforcement: 2,
    school: 3,
    bike_manufacturer: 4,
    software: 5,
    property_management: 6,
    other: 7
  }.freeze

  acts_as_paranoid
  mount_uploader :avatar, AvatarUploader

  belongs_to :parent_organization, class_name: "Organization"
  belongs_to :auto_user, class_name: 'User'

  has_many :recovered_records, through: :bikes
  has_many :locations, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :mail_snippets
  has_many :users, through: :memberships
  has_many :organization_invitations, dependent: :destroy
  has_many :organization_messages
  has_many :bike_organizations
  has_many :bikes, through: :bike_organizations
  has_many :b_params
  has_many :invoices
  has_many :payments
  has_many :bike_codes
  has_many :child_organizations, class_name: "Organization", foreign_key: :parent_organization_id
  has_many :creation_states
  has_many :created_bikes, through: :creation_states, source: :bike
  has_many :public_images, as: :imageable, dependent: :destroy # For organization landings and other paid features
  accepts_nested_attributes_for :mail_snippets
  accepts_nested_attributes_for :locations, allow_destroy: true

  enum kind: KIND_ENUM

  validates_presence_of :name
  validates_uniqueness_of :slug, message: "Slug error. You shouldn't see this - please contact admin@bikeindex.org"

  default_scope { order(:name) }

  scope :shown_on_map, -> { where(show_on_map: true, approved: true) }
  scope :paid, -> { where(is_paid: true) }
  scope :valid, -> { where(is_suspended: false) }
  # Eventually there will be other actions beside organization_messages, but for now it's just messages
  scope :with_bike_actions, -> { where("paid_feature_slugs ?| array[:keys]", keys: ["messages"]) }

  before_validation :set_calculated_attributes
  after_commit :update_user_bike_actions_organizations

  attr_accessor :embedable_user_email, :lightspeed_cloud_api_key

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.friendly_find(n)
    return nil unless n.present?
    return find(n) if integer_slug?(n)
    find_by_slug(Slugifyer.slugify(n)) || find_by_name(n) # Fallback, search by name just in case
  end

  def self.integer_slug?(n)
    n.is_a?(Integer) || n.match(/\A\d*\z/).present?
  end

  def self.admin_text_search(n)
    str = "%#{n.strip}%"
    match_cols = %w(organizations.name organizations.short_name locations.name locations.city)
    joins("LEFT OUTER JOIN locations AS locations ON organizations.id = locations.organization_id")
      .distinct
      .where(match_cols.map { |col| "#{col} ILIKE :str" }.join(' OR '), { str: str })
  end

  def to_param
    slug
  end

  def mail_snippet_body(type)
    return nil unless MailSnippet.organization_snippet_types.include?(type)
    snippet = mail_snippets.enabled.where(name: type).first
    snippet && snippet.body
  end

  def message_kinds # Matches organization_message kinds
    [
      paid_for?("geolocated_messages") ? "geolocated_messages" : nil,
      paid_for?("abandoned_bike_messages") ? "abandoned_bike_messages" : nil
    ].compact
  end

  def additional_registration_fields
    PaidFeature::REG_FIELDS.select { |f| paid_for?(f) }
  end

  def include_field_reg_phone?(user = nil)
    return false unless additional_registration_fields.include?("reg_phone")
    !user&.phone&.present?
  end

  def include_field_reg_address?(user = nil)
    additional_registration_fields.include?("reg_address")
  end

  def include_field_reg_secondary_serial?(user = nil)
    additional_registration_fields.include?("reg_secondary_serial")
  end

  def bike_actions? # Eventually there will be other actions beside organization_messages, so use this as general reference
    message_kinds.any?
  end

  def paid_for?(feature_name)
    return false unless feature_name.present? && paid_feature_slugs.is_a?(Array)
    # If kinds is an array, make sure they all are permitted kinds
    if feature_name.is_a?(Array)
      return false unless feature_name.any? # If they passed an empty array, it's false
      return feature_name.none? { |k| !paid_for?(k) }
    end
    paid_feature_slugs.include?(feature_name.strip.downcase.gsub(/\s/, "_")) # gnarly custom slug function because fml
  end

  def set_calculated_attributes
    return true unless name.present?
    self.name = strip_tags(name)
    self.name = "Stop messing about" unless name[/\d|\w/].present?
    self.website = Urlifyer.urlify(website) if website.present?
    self.short_name = (short_name || name).truncate(30)
    self.is_paid = true if current_invoice&.paid_in_full?
    self.kind ||= "other" # We need to always have a kind specified - generally we catch this, but just in case...
    # For now, just use them. However - nesting organizations probably need slightly modified paid_feature slugs
    self.paid_feature_slugs = current_invoice&.feature_slugs || []
    new_slug = Slugifyer.slugify(self.short_name).gsub(/\Aadmin/, '')
    if new_slug != slug
      # If the organization exists, don't invalidate because of it's own slug
      orgs = id.present? ? Organization.where('id != ?', id) : Organization.all
      while orgs.where(slug: new_slug).exists?
        i = i.present? ? i + 1 : 2
        new_slug = "#{new_slug}-#{i}"
      end
      self.slug = new_slug
    end
    generate_access_token unless self.access_token.present?
    set_auto_user
    update_user_bike_actions_organizations
    locations.each { |l| l.save unless l.shown == allowed_show }
    true # TODO: Rails 5 update
  end

  def ensure_auto_user
    return true if auto_user.present?
    self.embedable_user_email = users.first && users.first.email || ENV['AUTO_ORG_MEMBER']
    save
  end

  def current_invoice; invoices.active.last || parent_organization&.current_invoice end # Parent invoice serves as invoice
  def child_ids; child_organizations.pluck(:id) end

  def incomplete_b_params
    BParam.where(organization_id: child_ids + [id]).partial_registrations.without_bike
  end

  # TODO: these are DEPRECATED and should be REPLACED with paid_for?
  # I'm trying to ammass a list of paid features here (also in admin organization show)
  def bike_search?; has_bike_search end
  def show_recoveries?; has_bike_search end
  def show_bulk_import?; show_bulk_import end
  def show_partial_registrations?; show_partial_registrations end

  # Can be improved later, for now just always get a location for the map
  def map_focus_coordinates
    location = locations&.first
    {
      latitude: location&.latitude || 37.7870322,
      longitude: location&.longitude || -122.4061122
    }
  end

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

  def update_user_bike_actions_organizations
    if bike_actions?
      users.where("bike_actions_organization_id IS NULL or bike_actions_organization_id != ?", id)
    else
      users.where(bike_actions_organization_id: id)
    end.each { |u| u.update_attributes(updated_at: Time.now) } # Force updating
  end

  def allowed_show
    show_on_map && approved
  end

  def display_avatar
    is_paid && avatar.present?
  end

  def suspended?
    is_suspended?
  end

  def generate_access_token
    begin
      self.access_token = SecureRandom.hex
    end while self.class.exists?(access_token: access_token)
  end
end
