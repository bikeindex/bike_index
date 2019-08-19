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
    other: 7,
    ambassador: 8,
    bike_depot: 9,
  }.freeze

  POS_KIND_ENUM = {
    no_pos: 0,
    other_pos: 1,
    lightspeed_pos: 2,
    ascend_pos: 3,
    broken_pos: 4,
    does_not_need_pos: 5,
  }.freeze

  acts_as_paranoid
  mount_uploader :avatar, AvatarUploader

  belongs_to :parent_organization, class_name: "Organization"
  belongs_to :auto_user, class_name: "User"

  has_many :recovered_records, through: :bikes
  has_many :locations, inverse_of: :organization, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :mail_snippets
  has_many :users, through: :memberships
  has_many :organization_messages
  has_many :bike_organizations
  has_many :bikes, through: :bike_organizations
  has_many :b_params
  has_many :invoices
  has_many :payments
  has_many :bike_codes
  has_many :calculated_children, class_name: "Organization", foreign_key: :parent_organization_id
  has_many :creation_states
  has_many :created_bikes, through: :creation_states, source: :bike
  has_many :public_images, as: :imageable, dependent: :destroy # For organization landings and other paid features
  accepts_nested_attributes_for :mail_snippets
  accepts_nested_attributes_for :locations, allow_destroy: true

  enum kind: KIND_ENUM
  enum pos_kind: POS_KIND_ENUM

  validates_presence_of :name
  validates_uniqueness_of :short_name, case_sensitive: false, message: "another organization has this abbreviation - if you don't think that should be the case, contact support@bikeindex.org"
  validates_uniqueness_of :slug, message: "Slug error. You shouldn't see this - please contact support@bikeindex.org"

  default_scope { order(:name) }
  scope :shown_on_map, -> { where(show_on_map: true, approved: true) }
  scope :paid, -> { where(is_paid: true) }
  scope :unpaid, -> { where(is_paid: true) }
  scope :approved, -> { where(is_suspended: false, approved: true) }
  # Eventually there will be other actions beside organization_messages, but for now it's just messages
  scope :bike_actions, -> { where("paid_feature_slugs ?| array[:keys]", keys: %w[messages unstolen_notifications impound_bikes]) }

  before_validation :set_calculated_attributes
  after_commit :update_associations

  attr_accessor :embedable_user_email, :lightspeed_cloud_api_key, :skip_update

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.pos_kinds; POS_KIND_ENUM.keys.map(&:to_s) end

  def self.admin_required_kinds; %w[ambassador bike_depot].freeze end

  def self.user_creatable_kinds; kinds - admin_required_kinds end

  def self.friendly_find(n)
    return nil unless n.present?
    return n if n.is_a?(Organization)
    return find_by_id(n) if integer_slug?(n)
    slug = Slugifyer.slugify(n)
    # First try slug, then previous slug, and finally, just give finding by name a shot
    find_by_slug(slug) || find_by_previous_slug(slug) || where("LOWER(name) = LOWER(?)", n.downcase).first
  end

  def self.integer_slug?(n)
    n.is_a?(Integer) || n.match(/\A\d*\z/).present?
  end

  def self.admin_text_search(n)
    return nil unless n.present?
    # Only search for paid features if the text is paid features
    return with_paid_feature_slugs(n) if PaidFeature.matching_slugs(n).present?
    str = "%#{n.strip}%"
    match_cols = %w(organizations.name organizations.short_name locations.name locations.city)
    joins("LEFT OUTER JOIN locations AS locations ON organizations.id = locations.organization_id")
      .distinct
      .where(match_cols.map { |col| "#{col} ILIKE :str" }.join(" OR "), { str: str })
  end

  def self.with_paid_feature_slugs(slugs)
    matching_slugs = PaidFeature.matching_slugs(slugs)
    return nil unless matching_slugs.present?
    where("paid_feature_slugs ?& array[:keys]", keys: matching_slugs)
  end

  def impounded_bikes
    Bike.includes(:impound_records)
        .where(impound_records: { retrieved_at: nil, organization_id: id })
        .where.not(impound_records: { id: nil })
  end

  def to_param; slug end

  def sent_invitation_count; memberships.count end

  def remaining_invitation_count; available_invitation_count - sent_invitation_count end

  def ascend_imports?; ascend_name.present? end

  def parent?; child_ids.present? end

  def child_organizations; Organization.where(id: child_ids) end

  def mail_snippet_body(type)
    return nil unless MailSnippet.organization_snippet_types.include?(type)
    snippet = mail_snippets.enabled.where(name: type).first
    snippet && snippet.body
  end

  def message_kinds # Matches organization_message kinds
    [
      paid_for?("geolocated_messages") ? "geolocated_messages" : nil,
      paid_for?("abandoned_bike_messages") ? "abandoned_bike_messages" : nil,
    ].compact
  end

  def additional_registration_fields
    PaidFeature::REG_FIELDS.select { |f| paid_for?(f) }
  end

  def include_field_reg_affiliation?(user = nil)
    additional_registration_fields.include?("reg_affiliation")
  end

  def reg_affiliation_options; %w[student employee community_member] end

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

  def registration_field_label(field_slug)
    registration_field_labels && registration_field_labels[field_slug.to_s]
  end

  def bike_actions?
    message_kinds.any? || paid_for?("unstolen_notifications") || paid_for?("impound_bikes")
  end

  def law_enforcement_missing_verified_features?
    law_enforcement? && !paid_for?("unstolen_notifications")
  end

  def bike_shop_display_integration_alert?
    bike_shop? && %w[no_pos broken_pos].include?(pos_kind)
  end

  def paid_for?(feature_name)
    features =
      Array(feature_name)
        .map { |name| name.strip.downcase.gsub(/\s/, "_") }

    return false unless features.present? && paid_feature_slugs.is_a?(Array)

    features.all? do |feature|
      paid_feature_slugs.include?(feature) ||
      (ambassador? && feature == "unstolen_notifications")
    end
  end

  def set_calculated_attributes
    return true unless name.present?
    self.name = strip_tags(name)
    self.name = "Stop messing about" unless name[/\d|\w/].present?
    self.website = Urlifyer.urlify(website) if website.present?
    self.short_name = (short_name || name).truncate(30)
    self.is_paid = current_invoices.any? || current_parent_invoices.any?
    self.kind ||= "other" # We need to always have a kind specified - generally we catch this, but just in case...
    # For now, just use them. However - nesting organizations probably need slightly modified paid_feature slugs
    self.paid_feature_slugs = calculated_paid_feature_slugs
    new_slug = Slugifyer.slugify(self.short_name).gsub(/\Aadmin/, "")
    if new_slug != slug
      # If the organization exists, don't invalidate because of it's own slug
      orgs = id.present? ? Organization.unscoped.where("id != ?", id) : Organization.unscoped.all
      while orgs.where(slug: new_slug).exists?
        i = i.present? ? i + 1 : 2
        new_slug = "#{new_slug}-#{i}"
      end
      self.slug = new_slug
    end
    self.access_token ||= SecurityTokenizer.new_token
    self.child_ids = calculated_children.pluck(:id) || []
    set_auto_user
    set_ambassador_organization_defaults if ambassador?
    locations.each { |l| l.save unless l.shown == allowed_show }
    true # TODO: Rails 5 update
  end

  def ensure_auto_user
    return true if auto_user.present?
    self.embedable_user_email = users.first && users.first.email || ENV["AUTO_ORG_MEMBER"]
    save
  end

  def current_invoices; invoices.active end

  def current_parent_invoices; Invoice.where(organization_id: parent_organization_id).active end

  def incomplete_b_params
    BParam.where(organization_id: [*child_ids, id]).partial_registrations.without_bike
  end

  # Enable this if they have paid for showing it, or if they use ascend
  def show_bulk_import?; paid_for?("show_bulk_import") || ascend_imports? end

  def show_multi_serial?; paid_for?("show_multi_serial") || %w[law_enforcement].include?(kind); end

  # Can be improved later, for now just always get a location for the map
  def map_focus_coordinates
    location = locations&.first
    {
      latitude: location&.latitude || 37.7870322,
      longitude: location&.longitude || -122.4061122,
    }
  end

  def set_auto_user
    if embedable_user_email.present?
      u = User.fuzzy_email_find(embedable_user_email)
      self.auto_user_id = u.id if u && u.member_of?(self)
      if auto_user_id.blank? && embedable_user_email == ENV["AUTO_ORG_MEMBER"]
        Membership.create(user_id: u.id, organization_id: id, role: "member")
        self.auto_user_id = u.id
      end
    elsif auto_user_id.blank?
      return nil unless users.any?
      self.auto_user_id = users.first.id
    end
  end

  def calculated_pos_kind
    recent_bikes = bikes.where(created_at: (Time.current - 1.week)..Time.current)
    return "lightspeed_pos" if recent_bikes.lightspeed_pos.count > 0
    return "ascend_pos" if recent_bikes.ascend_pos.count > 0
    return "other_pos" if recent_bikes.any_pos.count > 0
    if bike_shop? && created_at < Time.current - 1.week
      return "does_not_need_pos" if recent_bikes.count > 2
    end
    bikes.any_pos.count > 0 ? "broken_pos" : "no_pos"
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

  def update_associations
    return true if skip_update
    parent_organization&.update_attributes(updated_at: Time.current, skip_update: true)
    calculated_children.each { |o| o.update_attributes(updated_at: Time.current, skip_update: true) }
  end

  private

  def calculated_paid_feature_slugs
    fslugs = current_invoices.feature_slugs
    return fslugs unless parent_organization_id.present?
    (fslugs + current_parent_invoices.map(&:child_paid_feature_slugs).flatten).uniq
  end

  def set_ambassador_organization_defaults
    self.show_on_map = false
    self.lock_show_on_map = false
    self.api_access_approved = false
    self.approved = true
    self.website = nil
    self.ascend_name = nil
    self.parent_organization_id = nil
  end
end
