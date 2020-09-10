class Organization < ApplicationRecord
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
    bike_depot: 9
  }.freeze

  POS_KIND_ENUM = {
    no_pos: 0,
    other_pos: 1,
    lightspeed_pos: 2,
    ascend_pos: 3,
    broken_lightspeed_pos: 4,
    does_not_need_pos: 5,
    broken_other_pos: 6
  }.freeze

  acts_as_paranoid

  mount_uploader :avatar, AvatarUploader

  belongs_to :parent_organization, class_name: "Organization"
  belongs_to :auto_user, class_name: "User"

  has_many :bike_organizations
  has_many :bikes, through: :bike_organizations
  has_many :recovered_records, through: :bikes

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  has_many :creation_states
  has_many :created_bikes, through: :creation_states, source: :bike

  has_many :locations, inverse_of: :organization, dependent: :destroy
  has_many :mail_snippets
  has_many :parking_notifications
  has_many :impound_records
  has_many :b_params
  has_many :invoices
  has_many :payments
  has_many :graduated_notifications
  has_many :calculated_children, class_name: "Organization", foreign_key: :parent_organization_id
  has_many :public_images, as: :imageable, dependent: :destroy # For organization landings and other organization features
  has_many :appointment_configurations, through: :locations
  has_many :appointments
  has_one :hot_sheet_configuration
  has_many :hot_sheets
  accepts_nested_attributes_for :mail_snippets
  accepts_nested_attributes_for :locations, allow_destroy: true

  enum kind: KIND_ENUM
  enum pos_kind: POS_KIND_ENUM
  enum manual_pos_kind: POS_KIND_ENUM, _prefix: :manual

  validates_presence_of :name
  validates_uniqueness_of :short_name, case_sensitive: false, message: "another organization has this abbreviation - if you don't think that should be the case, contact support@bikeindex.org"
  validates_with OrganizationNameValidator
  validates_uniqueness_of :slug, message: "Slug error. You shouldn't see this - please contact support@bikeindex.org"
  validates_with OrganizationNameValidator

  default_scope { order(:name) }
  scope :show_on_map, -> { where(show_on_map: true, approved: true) }
  scope :paid, -> { where(is_paid: true) }
  scope :unpaid, -> { where(is_paid: true) }
  scope :approved, -> { where(is_suspended: false, approved: true) }
  scope :broken_pos, -> { where(pos_kind: broken_pos_kinds) }
  # Eventually there will be other actions beside organization_messages, but for now it's just messages
  scope :bike_actions, -> { where("enabled_feature_slugs ?| array[:keys]", keys: %w[unstolen_notifications parking_notifications impound_bikes]) }
  # Regional orgs have to have the organization feature slug AND the search location set
  scope :regional, -> { where.not(location_latitude: nil).where.not(location_longitude: nil).where("enabled_feature_slugs ?| array[:keys]", keys: ["regional_bike_counts"]) }

  before_validation :set_calculated_attributes
  after_commit :update_associations

  delegate \
    :address,
    :city,
    :country,
    :country_id,
    :latitude,
    :longitude,
    :state,
    :state_id,
    :street,
    :zipcode,
    :metric_units?,
    to: :default_location,
    allow_nil: true

  geocoded_by nil, latitude: :location_latitude, longitude: :location_longitude

  attr_accessor :embedable_user_email, :skip_update

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.pos_kinds
    POS_KIND_ENUM.keys.map(&:to_s)
  end

  def self.broken_pos_kinds
    %w[broken_other_pos broken_lightspeed_pos]
  end

  def self.no_pos_kinds
    %w[no_pos does_not_need_pos]
  end

  def self.admin_required_kinds
    %w[ambassador bike_depot].freeze
  end

  def self.user_creatable_kinds
    kinds - admin_required_kinds
  end

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
    # Only search for organization features if the text is organization features
    return with_enabled_feature_slugs(n) if OrganizationFeature.matching_slugs(n).present?
    str = "%#{n.strip}%"
    match_cols = %w[organizations.name organizations.short_name locations.name locations.city]
    joins("LEFT OUTER JOIN locations AS locations ON organizations.id = locations.organization_id")
      .distinct
      .where(match_cols.map { |col| "#{col} ILIKE :str" }.join(" OR "), {str: str})
  end

  def self.with_enabled_feature_slugs(slugs)
    matching_slugs = OrganizationFeature.matching_slugs(slugs)
    return none unless matching_slugs.present?
    where("enabled_feature_slugs ?& array[:keys]", keys: matching_slugs)
  end

  def self.permitted_domain_passwordless_signin
    where.not(passwordless_user_domain: nil).with_enabled_feature_slugs("passwordless_users")
  end

  def self.passwordless_email_matching(str)
    str = EmailNormalizer.normalize(str)
    return nil unless str.present? && str.count("@") == 1 && str.match?(/.@.*\../)
    domain = str.split("@").last
    permitted_domain_passwordless_signin.detect { |o| o.passwordless_user_domain == domain }
  end

  # never geocode, use default_location lat/long
  def should_be_geocoded?
    false
  end

  def to_param
    slug
  end

  def landing_html?
    landing_html.present?
  end

  def restrict_invitations?
    !enabled?("passwordless_users") && !passwordless_user_domain.present?
  end

  def sent_invitation_count
    memberships.count
  end

  def remaining_invitation_count
    available_invitation_count - sent_invitation_count
  end

  # Enable this if they have paid for showing it, or if they use ascend
  def show_bulk_import?
    enabled?("show_bulk_import") || ascend_pos?
  end

  def show_multi_serial?
    enabled?("show_multi_serial") || %w[law_enforcement].include?(kind)
  end

  def broken_pos?
    self.class.broken_pos_kinds.include?(pos_kind)
  end

  def any_pos?
    !self.class.no_pos_kinds.include?(pos_kind)
  end

  def allowed_show?
    show_on_map && approved
  end

  def paid?
    is_paid
  end

  def display_avatar?
    avatar.present?
  end

  def suspended?
    is_suspended?
  end

  def appointment_functionality_enabled?
    any_enabled?(OrganizationFeature::APPOINTMENT_FEATURES)
  end

  def hot_sheet_on?
    hot_sheet_configuration.present? && hot_sheet_configuration.on?
  end

  def current_invoices
    invoices.active
  end

  def current_parent_invoices
    Invoice.where(organization_id: parent_organization_id).active
  end

  def parent?
    child_ids.present?
  end

  def child_organizations
    Organization.where(id: child_ids)
  end

  def regional_parents
    self.class.regional.where("regional_ids @> ?", [id].to_json)
  end

  def default_impound_location
    enabled?("impound_bikes_locations") ? locations.default_impound_locations.first : nil
  end

  def bounding_box
    Geocoder::Calculations.bounding_box(search_coordinates, search_radius)
  end

  # Try for publicly_visible, fall back to whatever
  def default_location
    locations.publicly_visible.order(id: :asc).first || locations.order(id: :asc).first
  end

  def search_coordinates
    [location_latitude, location_longitude]
  end

  def search_coordinates_set?
    search_coordinates.all?(&:present?)
  end

  # Many, many things are triggered off of this, so using a method, since we'll probably change logic later
  def regional?
    enabled?("regional_bike_counts")
  end

  def overview_dashboard?
    parent? || regional?
  end

  def bike_stickers
    BikeSticker.where(organization_id: id).or(BikeSticker.where(secondary_organization_id: id))
  end

  def nearby_organizations
    # Have to do fancy dance to match null parent_organization_id values
    @nearby_organizations = nearby_organizations_including_siblings
      .where("parent_organization_id != ? or parent_organization_id is null", parent_organization_id)
  end

  def nearby_and_partner_organization_ids
    [id, parent_organization_id].compact + child_ids + nearby_organizations_including_siblings.pluck(:id)
  end

  def mail_snippet_body(snippet_kind)
    return nil unless MailSnippet.organization_snippet_kinds.include?(snippet_kind)
    snippet = mail_snippets.enabled.where(kind: snippet_kind).first
    snippet&.body
  end

  def additional_registration_fields
    OrganizationFeature::REG_FIELDS.select { |f| enabled?(f) }
  end

  def include_field_organization_affiliation?(user = nil)
    additional_registration_fields.include?("organization_affiliation")
  end

  def organization_affiliation_options
    translation_scope =
      [:activerecord, :select_options, self.class.name.underscore, __method__]

    %w[student employee community_member]
      .map { |e| [I18n.t(e, scope: translation_scope), e] }
  end

  def include_field_reg_phone?(user = nil)
    return false unless additional_registration_fields.include?("reg_phone")
    !user&.phone&.present?
  end

  def include_field_reg_address?(user = nil)
    additional_registration_fields.include?("reg_address")
  end

  def include_field_extra_registration_number?(user = nil)
    additional_registration_fields.include?("extra_registration_number")
  end

  def registration_field_label(field_slug)
    registration_field_labels && registration_field_labels[field_slug.to_s]
  end

  def bike_actions?
    any_enabled?(OrganizationFeature::BIKE_ACTIONS)
  end

  def law_enforcement_missing_verified_features?
    law_enforcement? && !enabled?("unstolen_notifications")
  end

  def bike_shop_display_integration_alert?
    bike_shop? && %w[no_pos broken_other_pos broken_lightspeed_pos].include?(pos_kind)
  end

  # Bikes geolocated within `search_radius` miles.
  def nearby_bikes
    return Bike.none unless regional? && search_coordinates_set?
    # Need to unscope it so that we can call group-by on it
    Bike.unscoped.current.within_bounding_box(bounding_box)
  end

  def nearby_recovered_records
    return StolenRecord.none unless regional? && search_coordinates_set?
    # Don't use recovered scope because it orders them
    StolenRecord.recovered.within_bounding_box(bounding_box)
  end

  def deliver_graduated_notifications?
    enabled?("graduated_notifications") && graduated_notification_interval.present?
  end

  def graduated_notification_interval_days
    return nil unless graduated_notification_interval.present?
    graduated_notification_interval / ActiveSupport::Duration::SECONDS_PER_DAY
  end

  def graduated_notification_interval_days=(val)
    val_i = val.to_i
    self.graduated_notification_interval = val_i.days.to_i if val_i.present?
  end

  # Accepts string or array, tests that ALL are enabled
  def enabled?(feature_name)
    features =
      Array(feature_name)
        .map { |name| name.strip.downcase.gsub(/\s/, "_") }

    return false unless features.present? && enabled_feature_slugs.is_a?(Array)
    features.all? do |feature|
      enabled_feature_slugs.include?(feature) ||
        (ambassador? && feature == "unstolen_notifications")
    end
  end

  # Done multiple places, so consolidating. Might be worth optimizing
  def any_enabled?(features)
    features.detect { |f| enabled?(f) }.present?
  end

  def set_calculated_attributes
    return true unless name.present?
    self.name = strip_name_tags(name)
    self.name = "Stop messing about" unless name[/\d|\w/].present?
    self.website = Urlifyer.urlify(website) if website.present?
    self.short_name = (short_name || name).truncate(30)
    self.is_paid = current_invoices.any? || current_parent_invoices.any?
    self.kind ||= "other" # We need to always have a kind specified - generally we catch this, but just in case...
    self.passwordless_user_domain = EmailNormalizer.normalize(passwordless_user_domain)
    self.graduated_notification_interval = nil unless graduated_notification_interval.to_i > 0
    # For now, just use them. However - nesting organizations probably need slightly modified organization_feature slugs
    self.enabled_feature_slugs = calculated_enabled_feature_slugs.compact
    new_slug = Slugifyer.slugify(short_name).delete_prefix("admin")
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
    # NOTE: only organizations with child_organizations feature can be selected in admin view, but this doesn't block assignment
    self.child_ids = calculated_children.pluck(:id).presence || []
    self.regional_ids = nearby_organizations_including_siblings.pluck(:id) || []
    set_auto_user
    self.location_latitude = default_location&.latitude
    self.location_longitude = default_location&.longitude
    set_ambassador_organization_defaults if ambassador?
  end

  def ensure_auto_user
    return true if auto_user.present?
    self.embedable_user_email = users.first && users.first.email || ENV["AUTO_ORG_MEMBER"]
    save
  end

  def incomplete_b_params
    BParam.where(organization_id: [child_ids, id].flatten.compact).partial_registrations.without_bike
  end

  # Can be improved later, for now just always get a location for the map
  def map_focus_coordinates
    {
      latitude: default_location&.latitude || 37.7870322,
      longitude: default_location&.longitude || -122.4061122
    }
  end

  def set_auto_user
    if embedable_user_email.present?
      u = User.fuzzy_email_find(embedable_user_email)
      self.auto_user_id = u.id if u&.member_of?(self)
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
    return manual_pos_kind if manual_pos_kind.present?
    recent_bikes = bikes.where(created_at: (Time.current - 1.week)..Time.current)
    return "ascend_pos" if ascend_name.present? || recent_bikes.ascend_pos.count > 0
    return "lightspeed_pos" if recent_bikes.lightspeed_pos.count > 0
    return "other_pos" if recent_bikes.any_pos.count > 0
    if bike_shop? && recent_bikes.count > 2
      return "does_not_need_pos" if created_at < Time.current - 1.week ||
        bikes.where("bikes.created_at > ?", Time.current - 1.year).count > 100
    end
    return "broken_lightspeed_pos" if bikes.lightspeed_pos.count > 0
    bikes.any_pos.count > 0 ? "broken_other_pos" : "no_pos"
  end

  def update_associations
    return true if skip_update
    UpdateOrganizationAssociationsWorker.perform_async(id)
  end

  private

  def nearby_organizations_including_siblings
    return self.class.none unless regional? && search_coordinates_set?
    self.class.within_bounding_box(bounding_box).where.not(id: child_ids + [id, parent_organization_id])
      .reorder(id: :asc)
  end

  def strip_name_tags(str)
    strip_tags(name).gsub("&amp;", "&")
  end

  def calculated_enabled_feature_slugs
    fslugs = current_invoices.feature_slugs
    # If part of a region with bike_stickers, the organization receives the stickers organization feature
    if regional_parents.any?
      fslugs += ["bike_stickers"] if regional_parents.any? { |o| o.enabled?("bike_stickers") }
    end
    # If impound_bikes enabled and there is a default location for impounding bikes, add impound_bikes_locations
    if fslugs.include?("impound_bikes") && locations.impound_locations.any?
      fslugs += ["impound_bikes_locations"]
    end
    return fslugs unless parent_organization_id.present?
    (fslugs + current_parent_invoices.map(&:child_enabled_feature_slugs).flatten).uniq
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
