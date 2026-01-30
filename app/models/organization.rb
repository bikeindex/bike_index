# == Schema Information
#
# Table name: organizations
# Database name: primary
#
#  id                              :integer          not null, primary key
#  access_token                    :string(255)
#  api_access_approved             :boolean          default(FALSE), not null
#  approved                        :boolean          default(TRUE)
#  ascend_name                     :string
#  available_invitation_count      :integer          default(10)
#  avatar                          :string(255)
#  child_ids                       :jsonb
#  deleted_at                      :datetime
#  direct_unclaimed_notifications  :boolean          default(FALSE)
#  enabled_feature_slugs           :jsonb
#  graduated_notification_interval :bigint
#  is_paid                         :boolean          default(FALSE), not null
#  kind                            :integer
#  landing_html                    :text
#  lightspeed_register_with_phone  :boolean          default(FALSE)
#  location_latitude               :float
#  location_longitude              :float
#  lock_show_on_map                :boolean          default(FALSE), not null
#  manual_pos_kind                 :integer
#  name                            :string(255)
#  opted_into_theft_survey_2023    :boolean          default(FALSE)
#  passwordless_user_domain        :string
#  pos_kind                        :integer          default("no_pos")
#  previous_slug                   :string
#  regional_ids                    :jsonb
#  registration_field_labels       :jsonb
#  search_radius_miles             :float            default(50.0), not null
#  short_name                      :string(255)
#  show_on_map                     :boolean
#  slug                            :string(255)      not null
#  spam_registrations              :boolean          default(FALSE)
#  website                         :string(255)
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  auto_user_id                    :integer
#  manufacturer_id                 :bigint
#  parent_organization_id          :integer
#
# Indexes
#
#  index_organizations_on_location_latitude_and_location_longitude  (location_latitude,location_longitude)
#  index_organizations_on_manufacturer_id                           (manufacturer_id)
#  index_organizations_on_parent_organization_id                    (parent_organization_id)
#  index_organizations_on_slug                                      (slug) UNIQUE
#
class Organization < ApplicationRecord
  include ActionView::Helpers::SanitizeHelper
  include FriendlyNameFindable
  include SearchRadiusMetricable

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
    does_not_need_pos: 5,
    broken_lightspeed_pos: 4,
    broken_ascend_pos: 6
  }.freeze

  acts_as_paranoid

  mount_uploader :avatar, AvatarUploader

  belongs_to :parent_organization, class_name: "Organization"
  belongs_to :auto_user, class_name: "User"
  belongs_to :manufacturer

  has_many :bike_organizations
  has_many :bikes, through: :bike_organizations
  has_many :bike_organizations_ever_registered, -> { with_deleted }, class_name: "BikeOrganization"
  has_many :bikes_ever_registered, through: :bike_organizations_ever_registered, source: :bike
  has_many :recovered_records, through: :bikes_ever_registered

  has_many :organization_roles, dependent: :destroy
  has_many :users, through: :organization_roles

  has_many :admin_organization_roles, -> { admin }, class_name: "OrganizationRole"
  has_many :admins, through: :admin_organization_roles, source: :user

  has_many :ownerships
  has_many :created_bikes, through: :ownerships, source: :bike

  has_many :organization_manufacturers
  has_many :locations, inverse_of: :organization, dependent: :destroy
  has_many :mail_snippets
  has_many :parking_notifications
  has_many :impound_records
  has_many :impound_claims
  has_many :b_params
  has_many :invoices
  has_many :payments
  has_many :graduated_notifications
  has_many :organization_statuses
  has_many :calculated_children, class_name: "Organization", foreign_key: :parent_organization_id
  has_many :public_images, as: :imageable, dependent: :destroy # For organization landings and other organization features
  has_one :hot_sheet_configuration
  has_one :organization_stolen_message
  has_one :impound_configuration
  has_many :hot_sheets
  has_many :organization_model_audits
  accepts_nested_attributes_for :mail_snippets
  accepts_nested_attributes_for :organization_stolen_message
  accepts_nested_attributes_for :locations, allow_destroy: true

  enum :kind, KIND_ENUM
  enum :pos_kind, POS_KIND_ENUM
  enum :manual_pos_kind, POS_KIND_ENUM, prefix: :manual

  validates_presence_of :name
  validates_uniqueness_of :short_name, case_sensitive: false, message: I18n.t(:duplicate_short_name, scope: [:activerecord, :errors, :organization])
  validates_with OrganizationNameValidator
  validates_uniqueness_of :slug, message: "Slug error. You shouldn't see this - please contact support@bikeindex.org"
  validates_uniqueness_of :manufacturer_id, allow_blank: true

  default_scope { order(:name) }
  scope :name_ordered, -> { order(arel_table["name"].lower) }
  scope :show_on_map, -> { where(show_on_map: true, approved: true) }
  scope :paid, -> { where(is_paid: true) }
  scope :paid_money, -> { where(is_paid: true) } # TODO: make this actually show paid money, rather than just paid
  scope :unpaid, -> { where(is_paid: false) }
  scope :approved, -> { where(approved: true) }
  scope :broken_pos, -> { where(pos_kind: broken_pos_kinds) }
  scope :with_pos, -> { where(pos_kind: with_pos_kinds) }
  scope :with_stolen_message, -> { left_joins(:organization_stolen_message).where.not(organization_stolen_message: {body: nil}) }
  # Eventually there will be other actions beside organization_messages, but for now it's just messages
  scope :bike_actions, -> { where("enabled_feature_slugs ?| array[:keys]", keys: %w[unstolen_notifications parking_notifications impound_bikes]) }
  # Regional orgs have to have the organization feature slug AND the search location set
  scope :regional, -> { where.not(location_latitude: nil).where.not(location_longitude: nil).where("enabled_feature_slugs ?| array[:keys]", keys: ["regional_bike_counts"]) }

  before_validation :set_calculated_attributes
  after_commit :update_associations

  # delegate \
  #   :address,
  #   :city,
  #   :country,
  #   :country_id,
  #   :latitude,
  #   :longitude,
  #   :state,
  #   :state_id,
  #   :street,
  #   :zipcode,
  #   :metric_units?,
  #   to: :default_location,
  #   allow_nil: true

  geocoded_by nil, latitude: :location_latitude, longitude: :location_longitude

  attr_accessor :embedable_user_email, :skip_update

  class << self
    def kinds
      KIND_ENUM.keys.map(&:to_s)
    end

    def pos_kinds
      POS_KIND_ENUM.keys.map(&:to_s)
    end

    def broken_pos_kinds
      %w[broken_ascend_pos broken_lightspeed_pos].freeze
    end

    def without_pos_kinds
      %w[no_pos does_not_need_pos].freeze
    end

    def ascend_or_broken_ascend_kinds
      %w[ascend_pos broken_ascend_pos].freeze
    end

    def lightspeed_or_broken_lightspeed_kinds
      %w[lightspeed_pos broken_lightspeed_pos].freeze
    end

    def with_pos_kinds
      pos_kinds - broken_pos_kinds - without_pos_kinds
    end

    def pos?(kind = nil)
      kind.present? && !without_pos_kinds.include?(kind)
    end

    def admin_required_kinds
      %w[ambassador bike_depot].freeze
    end

    def user_creatable_kinds
      kinds - admin_required_kinds
    end

    def kind_humanized(str)
      str.blank? ? nil : str.to_s.titleize
    end

    def friendly_find(n)
      return nil unless n.present?
      return n if n.is_a?(Organization)
      return find_by_id(n) if integer_string?(n)

      slug = Slugifyer.slugify(n)
      # First try slug, then previous slug, and finally, just give finding by name a shot
      find_by_slug(slug) || find_by_previous_slug(slug) || where("LOWER(name) = LOWER(?)", n.downcase).first
    end

    def admin_text_search(n)
      return nil unless n.present?

      str = "%#{n.strip}%"
      match_cols = %w[organizations.name organizations.short_name organizations.ascend_name locations.name locations.city]
      joins("LEFT OUTER JOIN locations AS locations ON organizations.id = locations.organization_id")
        .distinct
        .where(match_cols.map { |col| "#{col} ILIKE :str" }.join(" OR "), {str: str})
    end

    def with_enabled_feature_slugs(slugs)
      matching_slugs = OrganizationFeature.matching_slugs(slugs)
      return none unless matching_slugs.present?

      where("enabled_feature_slugs ?& array[:keys]", keys: matching_slugs)
    end

    def with_any_enabled_feature_slugs(slugs)
      matching_slugs = OrganizationFeature.matching_slugs(slugs)
      return none unless matching_slugs.present?

      where("enabled_feature_slugs ?| array[:keys]", keys: matching_slugs)
    end

    def permitted_domain_passwordless_signin
      where.not(passwordless_user_domain: nil).with_enabled_feature_slugs("passwordless_users")
    end

    def passwordless_email_matching(str)
      str = EmailNormalizer.normalize(str)
      return nil unless str.present? && str.count("@") == 1 && str.match?(/.@.*\../)

      domain = str.split("@").last
      permitted_domain_passwordless_signin.detect { |o| o.passwordless_user_domain == domain }
    end

    def example
      Organization.find_by_id(92) || Organization.create(name: "Example organization")
    end
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
    organization_roles.count
  end

  def remaining_invitation_count
    available_invitation_count - sent_invitation_count
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def lightspeed_or_broken_lightspeed?
    self.class.lightspeed_or_broken_lightspeed_kinds.include?(pos_kind)
  end

  def ascend_or_broken_ascend?
    self.class.ascend_or_broken_ascend_kinds.include?(pos_kind)
  end

  # Enable this if they have paid for showing it, or if they use ascend
  def show_bulk_import?
    ascend_or_broken_ascend? || any_enabled?(%w[show_bulk_import show_bulk_import_impound show_bulk_import_stolen])
  end

  def show_multi_serial?
    enabled?("show_multi_serial") || %w[law_enforcement].include?(kind)
  end

  def public_impound_bikes?
    enabled?("impound_bikes_public") # feature slug applied in calculated_enabled_feature_slugs
  end

  # WARNING! This is not efficient
  def law_enforcement_features_enabled?
    law_enforcement? && current_invoices.any? { |i| i.law_enforcement_functionality_invoice? }
  end

  # Stub for now, but it might be more sophisticated later
  def impound_claims?
    public_impound_bikes?
  end

  def broken_pos?
    self.class.broken_pos_kinds.include?(pos_kind)
  end

  def pos?
    self.class.pos?(pos_kind)
  end

  def allowed_show?
    show_on_map && approved
  end

  # TODO: rename - actually should be "enabled_features?" - because many orgs haven't actually paid
  def paid?
    is_paid
  end

  # For now - just using paid
  def user_registration_all_bikes?
    paid? && !official_manufacturer? &&
      [36, 1].exclude?(id) # Exclude SBR and BikeIndex
  end

  def paid_money?
    paid? && current_invoices.any? { |i| i.paid_money_in_full? }
  end

  def paid_previously?
    !paid_money? && invoices.expired.any? { |i| i.was_active? }
  end

  def fetch_impound_configuration
    impound_configuration.present? ? impound_configuration : ImpoundConfiguration.create(organization_id: id)
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

  # Try for publicly_visible, fall back to whatever - TODO: make this configurable
  def default_location
    locations.publicly_visible.order(id: :asc).first || locations.order(id: :asc).first
  end

  # TODO: when default_location is configurable, use default location
  def metric_units?
    return @metric_units if defined?(@metric_units)

    default_country_id = if id.present?
      AddressRecord.organization.where(organization_id: id).reorder(:id).pick(:id)
    end
    @metric_units = Country.metric_units?(default_country_id)
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

  def official_manufacturer?
    enabled?("official_manufacturer")
  end

  def overview_dashboard?
    regional? || enabled?("claimed_ownerships") || official_manufacturer?
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

  def organization_view_counts
    return Organization.none unless manufacturer_id.present?

    Organization.left_joins(:organization_manufacturers)
      .where(organization_manufacturers: {can_view_counts: true, manufacturer_id: manufacturer_id})
  end

  def mail_snippet_body(snippet_kind)
    return nil unless MailSnippet.organization_snippet_kinds.include?(snippet_kind)

    snippet = mail_snippets.enabled.where(kind: snippet_kind).first
    snippet&.body
  end

  def current_organization_status
    organization_statuses.current.order(:start_at).limit(1).first
  end

  def additional_registration_fields
    OrganizationFeature::REG_FIELDS.select { |f| enabled?(f) }
  end

  def organization_affiliation_options
    translation_scope =
      [:activerecord, :select_options, self.class.name.underscore, __method__]

    %w[student graduate_student employee community_member]
      .map { |e| [I18n.t(e, scope: translation_scope), e] }
  end

  def block_short_name_edit?
    paid? # Prevent url changes breaking landing pages, etc
  end

  def bike_actions?
    any_enabled?(OrganizationFeature::BIKE_ACTIONS)
  end

  # bikes_member is slow - it's for graduated_notifications and shouldn't be called inline
  def bikes_member
    bikes.left_joins(:ownerships).where(ownerships: {current: true, user_id: users.pluck(:id)})
  end

  # bikes_not_member is slow - it's for graduated_notifications and shouldn't be called inline
  def bikes_not_member
    bikes.joins(:ownerships).where(ownerships: {current: true})
      .where.not(ownerships: {user_id: users.pluck(:id)})
      .or(bikes.joins(:ownerships).where(ownerships: {current: true, user_id: nil}))
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
    features = OrganizationFeature.matching_slugs(feature_name)
    return false unless features.present? && enabled_feature_slugs.is_a?(Array)

    features.all? { |feature| enabled_feature_slugs.include?(feature) }
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
    self.short_name = name_shortener(short_name || name)
    self.ascend_name = nil if ascend_name.blank?
    self.is_paid = current_invoices.any? || current_parent_invoices.any?
    self.kind ||= "other" # We need to always have a kind specified - generally we catch this, but just in case...
    self.passwordless_user_domain = EmailNormalizer.normalize(passwordless_user_domain)
    self.graduated_notification_interval = nil unless graduated_notification_interval.to_i > 0
    # For now, just use them. However - nesting organizations probably need slightly modified organization_feature slugs
    self.enabled_feature_slugs = calculated_enabled_feature_slugs.compact.sort
    new_slug = Slugifyer.slugify(short_name).delete_prefix("admin")
    if new_slug != slug
      # If the organization exists, don't invalidate because of it's own slug
      orgs = id.present? ? Organization.unscoped.where("id != ?", id) : Organization.unscoped.all
      # Force update the deleted short_names and slugs
      orgs.deleted.where.not("short_name ILIKE ?", "%-deleted")
        .each { |o| o.update_columns(short_name: "#{o.short_name}-deleted", slug: "#{o.slug}-deleted") }
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
        OrganizationRole.create(user_id: u.id, organization_id: id, role: "member")
        self.auto_user_id = u.id
      end
    elsif auto_user_id.blank?
      return nil unless users.any?

      self.auto_user_id = users.first.id
    end
  end

  def update_associations
    return true if skip_update

    UpdateOrganizationAssociationsJob.perform_async(id)
  end

  private

  def nearby_organizations_including_siblings
    return self.class.none unless regional? && search_coordinates_set?

    self.class.within_bounding_box(bounding_box).where.not(id: child_ids + [id, parent_organization_id])
      .reorder(id: :asc)
  end

  def strip_name_tags(str)
    Binxtils::InputNormalizer.sanitize(name&.strip).gsub("&amp;", "&")
  end

  def name_shortener(str)
    # Remove parens if the name is too long
    if str.length > 30 && str.match?(/\(.*\)/)
      str = str.gsub(/\(.*\)/, "")
    end
    str = str.gsub(/\s+/, " ").strip.truncate(30, omission: "", separator: " ").strip
    return str unless deleted_at.present?

    str.match?("-deleted") ? str : "#{str}-deleted"
  end

  def calculated_enabled_feature_slugs
    fslugs = current_invoices.feature_slugs
    # If part of a region with bike_stickers, the organization receives the stickers organization feature
    if regional_parents.any?
      if regional_parents.any? { |o| o.enabled?("bike_stickers") }
        fslugs += ["bike_stickers"]
        fslugs += ["bike_stickers_user_editable"] if regional_parents.any? { |o| o.enabled?("bike_stickers_user_editable") }
      end
    end
    # Ambassador orgs get unstolen_notifications
    fslugs += ["unstolen_notifications"] if ambassador?
    # Pull in the parent invoice features
    if parent_organization_id.present?
      fslugs += current_parent_invoices.map(&:child_enabled_feature_slugs).flatten
    end
    # If it has stickers, add reg_bike_sticker field
    fslugs += ["reg_bike_sticker"] if fslugs.include?("bike_stickers")

    if fslugs.include?("impound_bikes")
      # If impound_bikes enabled and there is a default location for impounding bikes, add impound_bikes_locations
      fslugs += ["impound_bikes_locations"] if locations.impound_locations.any?

      # Avoid loading impound_configuration on every request (since the menu needs to know)
      # Add a special feature, not included in organization_features
      fslugs += ["impound_bikes_public"] if impound_configuration&.public_view?
      # Also - don't fetch to avoid creating impound_configurations all the time
    end
    fslugs.uniq
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
