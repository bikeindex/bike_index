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

  has_many :bike_organizations
  has_many :bikes, through: :bike_organizations
  has_many :recovered_records, through: :bikes

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  has_many :creation_states
  has_many :created_bikes, through: :creation_states, source: :bike

  has_many :locations, inverse_of: :organization, dependent: :destroy
  has_many :mail_snippets
  has_many :organization_messages
  has_many :parking_notifications
  has_many :b_params
  has_many :invoices
  has_many :payments
  has_many :bike_stickers
  has_many :calculated_children, class_name: "Organization", foreign_key: :parent_organization_id
  has_many :public_images, as: :imageable, dependent: :destroy # For organization landings and other paid features
  accepts_nested_attributes_for :mail_snippets
  accepts_nested_attributes_for :locations, allow_destroy: true

  enum kind: KIND_ENUM
  enum pos_kind: POS_KIND_ENUM
  enum manual_pos_kind: POS_KIND_ENUM, _prefix: :manual

  validates_presence_of :name
  validates_uniqueness_of :short_name, case_sensitive: false, message: "another organization has this abbreviation - if you don't think that should be the case, contact support@bikeindex.org"
  validates_uniqueness_of :slug, message: "Slug error. You shouldn't see this - please contact support@bikeindex.org"

  default_scope { order(:name) }
  scope :shown_on_map, -> { includes(:locations).where(show_on_map: true, approved: true) }
  scope :paid, -> { where(is_paid: true) }
  scope :unpaid, -> { where(is_paid: true) }
  scope :approved, -> { where(is_suspended: false, approved: true) }
  # Eventually there will be other actions beside organization_messages, but for now it's just messages
  scope :bike_actions, -> { where("enabled_feature_slugs ?| array[:keys]", keys: %w[messages unstolen_notifications impound_bikes]) }
  # Regional orgs have to have the paid feature slug AND the search location set
  scope :regional, -> { where.not(location_latitude: nil).where.not(location_longitude: nil).where("enabled_feature_slugs ?| array[:keys]", keys: ["regional_bike_counts"]) }

  before_validation :set_calculated_attributes
  before_save :set_search_coordinates
  after_commit :update_associations

  delegate :city, :country, :zipcode, :state, to: :search_location, allow_nil: true

  geocoded_by nil, latitude: :location_latitude, longitude: :location_longitude
  after_validation :geocode, if: -> { false } # never geocode, use search_location lat/long

  attr_accessor :embedable_user_email, :lightspeed_cloud_api_key, :skip_update

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.pos_kinds; POS_KIND_ENUM.keys.map(&:to_s) end

  def self.no_pos_kinds; %w[no_pos does_not_need_pos] end

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
    return with_enabled_feature_slugs(n) if PaidFeature.matching_slugs(n).present?
    str = "%#{n.strip}%"
    match_cols = %w(organizations.name organizations.short_name locations.name locations.city)
    joins("LEFT OUTER JOIN locations AS locations ON organizations.id = locations.organization_id")
      .distinct
      .where(match_cols.map { |col| "#{col} ILIKE :str" }.join(" OR "), { str: str })
  end

  def self.with_enabled_feature_slugs(slugs)
    matching_slugs = PaidFeature.matching_slugs(slugs)
    return nil unless matching_slugs.present?
    where("enabled_feature_slugs ?& array[:keys]", keys: matching_slugs)
  end

  def impounded_bikes
    Bike.includes(:impound_records)
        .where(impound_records: { retrieved_at: nil, organization_id: id })
        .where.not(impound_records: { id: nil })
  end

  def parking_notification_bikes
    Bike.includes(:parking_notifications)
        .where(parking_notifications: { impound_record_id: nil, organization_id: id })
        .where.not(parking_notifications: { id: nil })
  end

  def to_param; slug end

  def sent_invitation_count; memberships.count end

  def remaining_invitation_count; available_invitation_count - sent_invitation_count end

  def parent?; child_ids.present? end

  def child_organizations; Organization.where(id: child_ids) end

  def bounding_box; Geocoder::Calculations.bounding_box(search_coordinates, search_radius) end

  def regional_parents; self.class.regional.where("regional_ids @> ?", [id].to_json) end

  def nearby_organizations
    return self.class.none unless regional? && search_coordinates_set?
    @nearby_organizations ||= self.class.within_bounding_box(bounding_box)
      .where.not(id: child_ids + [id])
      .reorder(id: :asc)
  end

  def nearby_and_partner_organization_ids
    [id] + child_ids + nearby_organizations.pluck(:id)
  end

  def mail_snippet_body(type)
    return nil unless MailSnippet.organization_snippet_types.include?(type)
    snippet = mail_snippets.enabled.where(name: type).first
    snippet&.body
  end

  def parking_notification_kinds; ParkingNotification.kinds end

  def message_kinds # Matches organization_message kinds
    [
      enabled?("geolocated_messages") ? "geolocated_messages" : nil,
      # TODO: make this based on abandoned_bikes
      enabled?("abandoned_bike_messages") ? "abandoned_bike_messages" : nil,
    ].compact
  end

  def message_kinds_except_abandoned # abandoned_bike_messages are going to be assigned dynamically and have different behavior
    message_kinds - ["abandoned_bike_messages"]
  end

  def additional_registration_fields
    PaidFeature::REG_FIELDS.select { |f| enabled?(f) }
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
    PaidFeature::BIKE_ACTIONS.detect { |f| enabled?(f) }.present?
  end

  def law_enforcement_missing_verified_features?
    law_enforcement? && !enabled?("unstolen_notifications")
  end

  def bike_shop_display_integration_alert?
    bike_shop? && %w[no_pos broken_pos].include?(pos_kind)
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

  def set_calculated_attributes
    return true unless name.present?
    self.name = strip_name_tags(name)
    self.name = "Stop messing about" unless name[/\d|\w/].present?
    self.website = Urlifyer.urlify(website) if website.present?
    self.short_name = (short_name || name).truncate(30)
    self.is_paid = current_invoices.any? || current_parent_invoices.any?
    self.kind ||= "other" # We need to always have a kind specified - generally we catch this, but just in case...
    # For now, just use them. However - nesting organizations probably need slightly modified paid_feature slugs
    self.enabled_feature_slugs = calculated_enabled_feature_slugs
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
    self.regional_ids = nearby_organizations.pluck(:id) || []
    set_auto_user
    set_ambassador_organization_defaults if ambassador?
    locations.each { |l| l.save unless l.shown == allowed_show }
  end

  def ensure_auto_user
    return true if auto_user.present?
    self.embedable_user_email = users.first && users.first.email || ENV["AUTO_ORG_MEMBER"]
    save
  end

  def current_invoices; invoices.active end

  def current_parent_invoices; Invoice.where(organization_id: parent_organization_id).active end

  def incomplete_b_params
    BParam.where(organization_id: [child_ids, id].flatten.compact).partial_registrations.without_bike
  end

  # Enable this if they have paid for showing it, or if they use ascend
  def show_bulk_import?; enabled?("show_bulk_import") || ascend_pos? end

  def show_multi_serial?; enabled?("show_multi_serial") || %w[law_enforcement].include?(kind); end

  def any_pos?; !self.class.no_pos_kinds.include?(pos_kind) end

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
    return manual_pos_kind if manual_pos_kind.present?
    recent_bikes = bikes.where(created_at: (Time.current - 1.week)..Time.current)
    return "ascend_pos" if ascend_name.present? || recent_bikes.ascend_pos.count > 0
    return "lightspeed_pos" if recent_bikes.lightspeed_pos.count > 0
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
    UpdateAssociatedOrganizationsWorker.perform_async(id)
  end

  def search_location
    locations.order(id: :asc).first
  end

  def search_coordinates
    [location_latitude, location_longitude]
  end

  def search_coordinates_set?
    search_coordinates.all?(&:present?)
  end

  def regional?
    enabled?("regional_bike_counts")
  end

  def overview_dashboard?
    parent? || regional?
  end

  private

  def strip_name_tags(str)
    strip_tags(name).gsub("&amp;", "&")
  end

  def set_search_coordinates
    return if search_coordinates_set?
    self.location_latitude = search_location&.latitude
    self.location_longitude = search_location&.longitude
  end

  def calculated_enabled_feature_slugs
    fslugs = current_invoices.feature_slugs
    # If part of a region with regional_stickers, the organization receives the stickers paid feature
    if regional_parents.any?
      fslugs += ["bike_stickers"] if regional_parents.any? { |o| o.enabled?("regional_stickers") }
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
