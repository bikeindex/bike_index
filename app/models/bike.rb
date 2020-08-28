class Bike < ApplicationRecord
  include ActiveModel::Dirty
  include BikeSearchable
  include Geocodeable

  acts_as_paranoid without_default_scope: true

  mount_uploader :pdf, PdfUploader
  process_in_background :pdf, CarrierWaveProcessWorker

  # For now, prefixed with status_ so it doesn't interfere with existing attrs
  STATUS_ENUM = {
    status_with_owner: 0,
    status_stolen: 1,
    status_abandoned: 2,
    status_impounded: 3,
    unregistered_parking_notification: 4
  }

  belongs_to :manufacturer
  belongs_to :primary_frame_color, class_name: "Color"
  belongs_to :secondary_frame_color, class_name: "Color"
  belongs_to :tertiary_frame_color, class_name: "Color"
  belongs_to :rear_wheel_size, class_name: "WheelSize"
  belongs_to :front_wheel_size, class_name: "WheelSize"
  belongs_to :rear_gear_type
  belongs_to :front_gear_type
  belongs_to :paint, counter_cache: true
  belongs_to :updator, class_name: "User"
  belongs_to :state
  belongs_to :country
  belongs_to :current_stolen_record, class_name: "StolenRecord"
  belongs_to :creator, class_name: "User" # to be deprecated and removed
  belongs_to :creation_organization, class_name: "Organization" # to be deprecated and removed

  has_many :bike_organizations, dependent: :destroy
  has_many :organizations, through: :bike_organizations
  has_many :can_edit_claimed_bike_organizations, -> { can_edit_claimed }, class_name: "BikeOrganization"
  has_many :can_edit_claimed_organizations, through: :can_edit_claimed_bike_organizations, source: :organization
  has_many :creation_states
  # delegate :creator, to: :creation_state, source: :creator
  # has_one :creation_organization, through: :creation_state, source: :organization
  has_many :stolen_notifications
  has_many :stolen_records
  has_many :other_listings, dependent: :destroy
  has_many :normalized_serial_segments, dependent: :destroy
  has_many :ownerships
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :components, dependent: :destroy
  has_many :bike_stickers
  has_many :b_params, foreign_key: :created_bike_id, dependent: :destroy
  has_many :duplicate_bike_groups, -> { unignored }, through: :normalized_serial_segments
  has_many :duplicate_bikes, through: :duplicate_bike_groups, class_name: "Bike", source: :bikes
  has_many :recovered_records, -> { recovered_ordered }, class_name: "StolenRecord"
  has_many :impound_records
  has_many :parking_notifications
  has_many :graduated_notifications, foreign_key: :bike_id

  accepts_nested_attributes_for :stolen_records
  accepts_nested_attributes_for :components, allow_destroy: true

  validates_presence_of :serial_number
  validates_presence_of :propulsion_type
  validates_presence_of :cycle_type
  validates_presence_of :creator, on: :create
  validates_presence_of :manufacturer_id

  validates_presence_of :primary_frame_color_id

  attr_accessor :other_listing_urls, :date_stolen, :receive_notifications, :has_no_serial, # has_no_serial included because legacy b_params, delete 2019-12
    :image, :b_param_id, :embeded, :embeded_extended, :paint_name,
    :bike_image_cache, :send_email, :skip_email, :marked_user_hidden, :marked_user_unhidden,
    :b_param_id_token, :parking_notification_kind, :skip_status_update, :manual_csr

  attr_writer :phone, :user_name, :organization_affiliation, :external_image_urls # reading is managed by a method

  enum frame_material: FrameMaterial::SLUGS
  enum handlebar_type: HandlebarType::SLUGS
  enum cycle_type: CycleType::SLUGS
  enum propulsion_type: PropulsionType::SLUGS
  enum status: STATUS_ENUM

  default_scope do
    includes(:tertiary_frame_color, :secondary_frame_color, :primary_frame_color, :current_stolen_record)
      .current
      .order("listing_order desc")
  end
  scope :current, -> { where(example: false, hidden: false, deleted_at: nil) }
  scope :stolen, -> { where(stolen: true) }
  scope :non_stolen, -> { where(stolen: false) }
  scope :abandoned, -> { where(abandoned: true) }
  scope :organized, -> { where.not(creation_organization_id: nil) }
  scope :with_known_serial, -> { where.not(serial_number: "unknown") }
  scope :impounded, -> { includes(:impound_records).where(impound_records: {resolved_at: nil}).where.not(impound_records: {id: nil}) }
  scope :non_abandoned, -> { where(abandoned: false) }
  scope :without_creation_state, -> { includes(:creation_states).where(creation_states: {id: nil}) }
  scope :lightspeed_pos, -> { includes(:creation_states).where(creation_states: {pos_kind: "lightspeed_pos"}) }
  scope :ascend_pos, -> { includes(:creation_states).where(creation_states: {pos_kind: "ascend_pos"}) }
  scope :any_pos, -> { includes(:creation_states).where.not(creation_states: {pos_kind: "no_pos"}) }
  scope :no_pos, -> { includes(:creation_states).where(creation_states: {pos_kind: "no_pos"}) }
  scope :example, -> { where(example: true) }
  scope :non_example, -> { where(example: false) }

  before_save :set_calculated_attributes

  include PgSearch::Model
  pg_search_scope :pg_search, against: {
    serial_number: "A",
    cached_data: "B",
    all_description: "C"
  }

  pg_search_scope :admin_search,
    against: {owner_email: "A"},
    associated_against: {ownerships: :owner_email, creator: :email},
    using: {tsearch: {dictionary: "english", prefix: true}}

  class << self
    def old_attr_accessible
      (%w[manufacturer_id manufacturer_other serial_number
        serial_normalized made_without_serial extra_registration_number
        creation_organization_id manufacturer year thumb_path name stolen
        current_stolen_record_id abandoned frame_material cycle_type frame_model number_of_seats
        handlebar_type handlebar_type_other frame_size frame_size_number frame_size_unit
        rear_tire_narrow front_wheel_size_id rear_wheel_size_id front_tire_narrow
        primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id paint_id paint_name
        propulsion_type street zipcode country_id state_id city belt_drive
        coaster_brake rear_gear_type_slug rear_gear_type_id front_gear_type_slug front_gear_type_id description owner_email
        timezone date_stolen receive_notifications phone creator creator_id image
        components_attributes b_param_id embeded embeded_extended example hidden
        stock_photo_url pdf send_email skip_email other_listing_urls listing_order approved_stolen
        marked_user_hidden marked_user_unhidden b_param_id_token is_for_sale bike_organization_ids].map(&:to_sym) + [stolen_records_attributes: StolenRecord.old_attr_accessible,
                                                                                                                     components_attributes: Component.old_attr_accessible]).freeze
    end

    def statuses
      STATUS_ENUM.keys.map(&:to_s)
    end

    def text_search(query)
      query.present? ? pg_search(query) : all
    end

    def organized_email_search(query)
      return all unless query.present?
      where("owner_email ilike ?", "%#{query.strip}%")
    end

    def admin_text_search(query)
      query.present? ? admin_search(query) : all
    end

    def friendly_find(bike_str)
      return nil unless bike_str.present?
      bike_str = bike_str.to_s.strip
      if /^\d+\z/.match?(bike_str) # it's only numbers, so it's a timestamp
        bike_id = bike_str
      else
        bike_id = bike_str.match(/bikes\/\d*/i)
        bike_id = bike_id && bike_id[0].gsub(/bikes./, "") || nil
      end
      where(id: bike_id).first
    end

    # This method only accepts numerical org ids
    def bike_sticker(organization_id = nil)
      return includes(:bike_stickers).where.not(bike_stickers: {bike_id: nil}) if organization_id.blank?
      includes(:bike_stickers).where(bike_stickers: {organization_id: organization_id})
    end

    # This method doesn't accept org_id because Seth got lazy
    def no_bike_sticker
      includes(:bike_stickers).where(bike_stickers: {bike_id: nil})
    end

    def organization(org_or_org_ids)
      ids = org_or_org_ids.is_a?(Organization) ? Organization.friendly_find(org_or_org_ids)&.id : org_or_org_ids
      includes(:bike_organizations).where(bike_organizations: {organization_id: ids})
    end

    # Possibly-found bikes are stolen bikes that have a counterpart record(s)
    # (matching by normalized serial number) in an abandoned state.
    def possibly_found
      unscoped
        .current
        .stolen
        .non_abandoned
        .where(serial_normalized: abandoned.non_stolen.select(:serial_normalized))
    end

    # Return an array of tuples, each pairing a possibly-found bike with a
    # counterpart abandoned bike.
    def possibly_found_with_match
      matches_by_serial =
        unscoped
          .current
          .abandoned
          .non_stolen
          .where.not(serial_normalized: nil)
          .group_by(&:serial_normalized)

      possibly_found
        .select { |bike| matches_by_serial.key?(bike.serial_normalized) }
        .map { |bike| [bike, matches_by_serial[bike.serial_normalized]] }
        .flat_map { |bike, matches| matches.map { |match| [bike, match] } }
        .reject { |bike, match| bike.owner_email == match.owner_email }
    end

    # Externally possibly-found bikes are stolen bikes that have a counterpart
    # record(s) (matching by normalized serial number) in an external registry.
    #
    # External-registry searches can be delimited by country by passing
    # `country_iso`.
    def possibly_found_externally(country_iso: "NL")
      normalized_serials =
        ExternalRegistryBike
          .where(country: Country.where(iso: country_iso))
          .where.not(serial_normalized: nil)
          .select(:serial_normalized)
          .distinct
          .pluck(:serial_normalized)

      unscoped
        .current
        .currently_stolen_in(country: country_iso)
        .non_abandoned
        .where(serial_normalized: normalized_serials)
    end

    # Return an array of tuples, each pairing a possibly-found bike with a
    # counterpart possible match found on an external registry associated with
    # the given `country_iso`.
    def possibly_found_externally_with_match(country_iso: "NL")
      matches_by_serial =
        ExternalRegistryBike
          .where(country: Country.where(iso: country_iso))
          .where.not(serial_normalized: nil)
          .group_by(&:serial_normalized)

      possibly_found_externally(country_iso: country_iso)
        .select { |bike| matches_by_serial.key?(bike.serial_normalized) }
        .map { |bike| [bike, matches_by_serial[bike.serial_normalized]] }
        .flat_map { |bike, matches| matches.map { |match| [bike, match] } }
    end

    # Search for currently stolen bikes reported stolen in the given city, state
    # and/or country. `city`, `state` and `country` are accepted as strings /
    # symbols of the name or abbreviation, and are matched conjointly.
    def currently_stolen_in(city: nil, state: nil, country: nil)
      location = {city: city, state: state, country: country}.select { |_, v| v.present? }
      location[:state] &&= State.find_by("name = ? OR abbreviation = ?", state, state)
      location[:country] &&= Country.find_by("name = ? OR iso = ?", country, country)
      return none if location.values.any?(&:blank?)

      unscoped
        .stolen
        .current
        .with_known_serial
        .includes(:current_stolen_record)
        .where(stolen_records: location)
    end
  end

  # We don't actually want to show these messages to the user, since they just tell us the bike wasn't created
  def cleaned_error_messages
    errors.full_messages.reject { |m| m[/(bike can.t be blank|are you sure the bike was created)/i] }
  end

  def calculated_listing_order
    return current_stolen_record.date_stolen.to_i.abs if stolen && current_stolen_record.present?
    t = (updated_at || Time.current).to_i / 10000
    stock_photo_url.present? || public_images.present? ? t : t / 100
  end

  def credibility_scorer
    CredibilityScorer.new(self)
  end

  def creation_state
    creation_states.first
  end

  def creation_description
    creation_state&.creation_description
  end

  def bulk_import
    creation_state&.bulk_import
  end

  def pos_kind
    creation_state&.pos_kind
  end

  def pos?
    pos_kind.present? && pos_kind != "no_pos"
  end

  def current_ownership
    ownerships.reorder(:id).last
  end

  # Use present? to ensure true/false rather than nil
  def claimed?
    current_ownership.present? && current_ownership.claimed.present?
  end

  # owner resolves to creator if user isn't present, or organization auto user. shouldn't ever be nil
  def owner
    current_ownership&.owner
  end

  # This can be nil!
  def user
    current_ownership&.user
  end

  def user?
    user.present?
  end

  def stolen_recovery?
    recovered_records.any?
  end

  def current_impound_record
    impound_records.current.last
  end

  def impounded?
    current_impound_record.present?
  end

  def avery_exportable?
    owner_name.present? && valid_registration_address_present?
  end

  def current_parking_notification
    parking_notifications.current.first
  end

  # Small helper because we call this a lot
  def type
    cycle_type && cycle_type_name.downcase
  end

  def user_hidden
    hidden && current_ownership&.user_hidden
  end

  def email_visible_for?(org)
    organizations.include?(org)
  end

  def serial_display
    return "Hidden" if abandoned
    return serial_number.humanize if no_serial?
    serial_number
  end

  # We may eventually remove the boolean. For now, we're just going with it.
  def made_without_serial?
    made_without_serial
  end

  def serial_unknown?
    serial_number == "unknown"
  end

  def no_serial?
    made_without_serial? || serial_unknown?
  end

  # This is for organizations - might be useful for admin as well. We want it to be nil if it isn't present
  # User - not ownership, because we don't want registrar
  def owner_name
    return user.name if user&.name.present?
    # Only look deeper for the name if it's the first owner - or if no owner, which means testing probably
    return nil unless current_ownership.blank? || current_ownership&.first?
    oname = b_params.map(&:user_name).reject(&:blank?).first
    return oname if oname.present?
    # If this bike is unclaimed and was created by an organization member, then we don't have an owner_name
    return nil if creation_organization.present? && owner&.member_of?(creation_organization)
    owner&.name
  end

  def first_ownership
    ownerships.reorder(:id).first
  end

  def organized?(org = nil)
    if org.present?
      bike_organization_ids.include?(org.id)
    else
      bike_organizations.any?
    end
  end

  def graduated_notifications(org = nil)
    return GraduatedNotification.none unless org.present?
    org.graduated_notifications.where(bike_id: id)
  end

  def graduated?(org = nil)
    graduated_notifications(org).active.any?
  end

  # check if this is the first ownership - or if no owner, which means testing probably
  def first_ownership?
    current_ownership&.blank? || current_ownership == first_ownership
  end

  def editable_organizations
    # Only the impound organization can edit it if it's impounded
    return Organization.where(id: current_impound_record.organization_id) if current_impound_record.present?
    return organizations if first_ownership? && organized? && !claimed?
    can_edit_claimed_organizations
  end

  def authorized_by_organization?(u: nil, org: nil)
    editable_organization_ids = editable_organizations.pluck(:id)
    return false unless editable_organization_ids.any?
    return true unless u.present? || org.present?
    # We have either a org or a user - if no user, we only need to check org
    return editable_organization_ids.include?(org.id) if u.blank?
    return false if claimable_by?(u) || u == owner # authorized by owner, not organization
    # Ensure the user is part of the organization and the organization can edit if passed both
    return u.member_of?(org) && editable_organization_ids.include?(org.id) if org.present?
    editable_organizations.any? { |o| u.member_of?(o) }
  end

  def first_owner_email
    first_ownership.owner_email
  end

  def claimable_by?(u)
    return false if u.blank? || current_ownership.blank? || current_ownership.claimed? || current_impound_record.present?
    user == u || current_ownership.claimable_by?(u)
  end

  def authorized?(u)
    return true unless current_impound_record.present? || !(u == owner || claimable_by?(u))
    return false if u.blank?
    authorized_by_organization?(u: u)
  end

  def authorize_and_claim_for_user(u)
    return authorized?(u) unless claimable_by?(u)
    current_ownership.mark_claimed
    true
  end

  def sticker_organizations
    organizations.with_enabled_feature_slugs("bike_stickers")
  end

  # This method only accepts numerical org ids
  def bike_sticker?(organization_id = nil)
    bike_stickers.where(organization_id.present? ? {organization_id: organization_id} : {}).any?
  end

  def display_contact_owner?(u = nil)
    stolen? && current_stolen_record.present?
  end

  def contact_owner?(u = nil, organization = nil)
    return false unless u.present?
    return true if stolen? && current_stolen_record.present?
    return false unless owner&.notification_unstolen
    return u.send_unstolen_notifications? unless organization.present? # Passed organization overrides user setting to speed stuff up
    organization.enabled?("unstolen_notifications") && u.member_of?(organization)
  end

  def contact_owner_user?
    user? || stolen?
  end

  def contact_owner_email
    contact_owner_user? ? owner_email : creator&.email
  end

  def phone
    # use @phone because attr_accessor
    @phone ||= current_stolen_record&.phone
    @phone ||= user&.phone
    # Only grab the phone number from b_params if this is the first_ownership
    @phone ||= b_params.map(&:phone).reject(&:blank?).first if first_ownership?
    @phone
  end

  def phoneable_by?(passed_user = nil)
    return false unless phone.present?
    return true if passed_user&.superuser
    if current_stolen_record.blank?
      return false unless contact_owner?(passed_user) # This return false if user isn't present
      return !passed_user.ambassador? # we aren't giving ambassadors access to phones rn
    end
    return true if current_stolen_record.phone_for_everyone
    return false if passed_user.blank?
    return true if current_stolen_record.phone_for_shops && passed_user.has_shop_membership?
    return true if current_stolen_record.phone_for_police && passed_user.has_police_membership?
    current_stolen_record.phone_for_users
  end

  def visible_by?(passed_user = nil)
    return true unless hidden || deleted?
    if passed_user.present?
      return true if passed_user.superuser?
      return false if deleted?
      return true if user_hidden && authorized?(passed_user)
    end
    false
  end

  def fetch_current_stolen_record
    return current_stolen_record if defined?(manual_csr)
    # Don't access through association, or else it won't find without a reload
    self.current_stolen_record = StolenRecord.where(bike_id: id, current: true).reorder(:id).last
  end

  def frame_model_truncated
    frame_model&.truncate(40)
  end

  def title_string
    t = [year, mnfg_name, frame_model_truncated].join(" ")
    t += " #{type}" if type != "bike"
    Rails::Html::FullSanitizer.new.sanitize(t.gsub(/\s+/, " ")).strip
  end

  def stolen_string
    return nil unless stolen && current_stolen_record.present?
    [
      "Stolen ",
      current_stolen_record.date_stolen && current_stolen_record.date_stolen.strftime("%Y-%m-%d"),
      current_stolen_record.address && "from #{current_stolen_record.address}. "
    ].compact.join(" ")
  end

  def video_embed_src
    if video_embed.present?
      code = Nokogiri::HTML(video_embed)
      src = code.xpath("//iframe/@src")
      src[0]&.value
    end
  end

  def render_paint_description?
    return false unless pos? && primary_frame_color == Color.black
    secondary_frame_color_id.blank? && paint.present?
  end

  def bike_organization_ids
    bike_organizations.pluck(:organization_id)
  end

  def bike_organization_ids=(val)
    val = val.split(",").map(&:strip) unless val.is_a?(Array)

    org_ids = val.map { |id| validated_organization_id(id) }.compact

    org_ids.each { |id| bike_organizations.where(organization_id: id).first_or_create }

    bike_organizations
      .reject { |bo| org_ids.include?(bo.organization_id) }
      .each(&:destroy)
  end

  def validated_organization_id(organization_id)
    return nil unless organization_id.present?

    organization = Organization.friendly_find(organization_id)
    return organization.id if organization && !organization.suspended?

    if organization.present?
      suspended = I18n.t(:suspended, scope: %i[activerecord errors models bike])
      errors.add(:organizations, "#{organization_id} #{suspended}")
    else
      not_found = I18n.t(:not_found, scope: %i[activerecord errors models bike])
      errors.add(:organizations, "#{organization_id} #{not_found}")
    end

    nil
  end

  def set_mnfg_name
    n = if manufacturer.blank?
      ""
    elsif manufacturer.name == "Other" && manufacturer_other.present?
      Rails::Html::FullSanitizer.new.sanitize(manufacturer_other)
    else
      manufacturer.simple_name
    end
    self.mnfg_name = n.strip.truncate(60)
  end

  def set_user_hidden
    return true unless current_ownership.present? # If ownership isn't present (eg during creation), nothing to do
    if marked_user_hidden.present? && ParamsNormalizer.boolean(marked_user_hidden)
      self.hidden = true
      current_ownership.update_attribute :user_hidden, true unless current_ownership.user_hidden
    elsif marked_user_unhidden.present? && ParamsNormalizer.boolean(marked_user_unhidden)
      self.hidden = false
      current_ownership.update_attribute :user_hidden, false if current_ownership.user_hidden
    end
    true
  end

  def normalize_emails
    self.owner_email = if User.fuzzy_email_find(owner_email)
      User.fuzzy_email_find(owner_email).email
    else
      EmailNormalizer.normalize(owner_email)
    end
    true
  end

  def normalize_serial_number
    if made_without_serial?
      self.serial_number = "made_without_serial"
      self.serial_normalized = nil
      return true
    end

    self.serial_number = SerialNormalizer.unknown_and_absent_corrected(serial_number)

    case serial_number
    when "made_without_serial"
      self.serial_normalized = nil
      self.made_without_serial = true
    when "unknown"
      self.serial_normalized = nil
      self.made_without_serial = false
    else
      self.serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
      self.made_without_serial = false
    end

    true
  end

  def create_normalized_serial_segments
    SerialNormalizer.new(serial: serial_number).save_segments(id)
  end

  def clean_frame_size
    return true unless frame_size.present? || frame_size_number.present?
    if frame_size.present? && frame_size.match(/\d+\.?\d*/).present?
      self.frame_size_number = frame_size.match(/\d+\.?\d*/)[0].to_f
    end

    unless frame_size_unit.present?
      self.frame_size_unit = if frame_size_number.present?
        if frame_size_number < 30 # Good guessing?
          "in"
        else
          "cm"
        end
      else
        "ordinal"
      end
    end

    self.frame_size = if frame_size_number.present?
      frame_size_number.to_s.gsub(".0", "") + frame_size_unit
    else
      case frame_size.downcase
                        when /x*sma/, "xs"
                          "xs"
                        when /sma/, "s"
                          "s"
                        when /med/, "m"
                          "m"
                        when /(lg)|(large)/, "l"
                          "l"
                        when /x*l/, "xl"
                          "xl"
      end
    end
    true
  end

  def set_paints
    self.paint_id = nil if paint_id.present? && paint_name.blank? && !paint_name.nil?
    return true unless paint_name.present?
    self.paint_name = paint_name[0] if paint_name.is_a?(Array)
    return true if Color.friendly_find(paint_name).present?
    paint = Paint.friendly_find(paint_name)
    paint = Paint.create(name: paint_name) unless paint.present?
    self.paint_id = paint.id
  end

  def paint_description
    paint.name.titleize if paint.present?
  end

  def valid_registration_address_present?
    return false if registration_address.blank?
    registration_address["street"].present? && registration_address["city"].present?
  end

  def address_source
    # TODO: make this return where the address is coming from
  end

  # Goes along with organization additional_registration_fields
  def registration_address
    return @registration_address if defined?(@registration_address)

    @registration_address = if user&.address_present?
      user&.address_hash
    elsif address_set_manually
      address_hash
    else
      b_params_address || {}
    end
  end

  # Set the bike's location data (lat/long, city, postal code, country, etc.)
  #
  # Geolocate based on the full current stolen record address, if available.
  # Otherwise, use the data set by set_location_info.
  # Sets lat/long, will avoid a geocode API call if coordinates are found
  def set_location_info
    if current_stolen_record.present?
      # If there is a current stolen - even if it has a blank location - use it
      # It's used for searching and displaying stolen bikes, we don't want other information leaking
      self.attributes = if address_set_manually # Only set coordinates if the address is set manually
        current_stolen_record.attributes.slice("latitude", "longitude")
      else # Set the whole address from the stolen record
        current_stolen_record.address_hash
      end
    else
      return true if address_set_manually # If it's not stolen, use the manual set address for the coordinates
      address_attrs = location_record_address_hash
      return true unless address_attrs.present? # No address hash present so skip
      self.attributes = address_attrs
    end
  end

  def organization_affiliation
    b_params.map { |bp| bp.organization_affiliation }.compact.join(", ")
  end

  def external_image_urls
    b_params.map { |bp| bp.external_image_urls }.flatten.reject(&:blank?).uniq
  end

  def alert_image_url(version = nil)
    current_stolen_record&.current_alert_image&.image_url(version)
  end

  def load_external_images(urls = nil)
    (urls || external_image_urls).reject(&:blank?).each do |url|
      next if public_images.where(external_image_url: url).present?
      public_images.create(external_image_url: url)
    end
  end

  def frame_colors
    [
      primary_frame_color&.name,
      secondary_frame_color&.name,
      tertiary_frame_color&.name
    ].compact
  end

  # list of cgroups so that we can arrange them
  def cgroup_array
    components.map(&:cgroup_id).uniq
  end

  def cache_photo
    self.thumb_path = public_images && public_images.first && public_images.first.image_url(:small)
  end

  def set_calculated_attributes
    fetch_current_stolen_record # grab the current stolen record first, it's used by a bunch of things
    self.stolen = true if current_stolen_record.present? && !current_stolen_record.recovered? # Only assign if present
    set_location_info
    self.listing_order = calculated_listing_order
    # Quick hack to store the fact that it was creation for parking notification
    if unregistered_parking_notification?
      self.created_by_parking_notification = true
      # TODO: Switch to using creation_state, rather than this boolean, ASAP
      if creation_state.present? && creation_state.origin != "unregistered_parking_notification"
        creation_state.update(origin: "unregistered_parking_notification")
      end
    end
    self.status = calculated_status unless skip_status_update
    self.abandoned = true if status_abandoned? # Quick hack to manage prior to status update
    clean_frame_size
    set_mnfg_name
    set_user_hidden
    normalize_emails
    normalize_serial_number
    set_paints
    cache_bike
  end

  def components_cache_string
    components.includes(:manufacturer, :ctype).map.each do |c|
      if c.ctype.present? && c.ctype.name.present?
        [
          c.year,
          c.manufacturer&.name,
          c.component_type
        ]
      end
    end
  end

  def cache_stolen_attributes
    self.all_description =
      [description, current_stolen_record&.theft_description]
      .reject(&:blank?)
      .join(" ")
  end

  def cache_bike
    cache_stolen_attributes
    cache_photo
    self.cached_data = [
      mnfg_name,
      (propulsion_type_name == "Foot pedal" ? nil : propulsion_type_name),
      year,
      (primary_frame_color && primary_frame_color.name),
      (secondary_frame_color && secondary_frame_color.name),
      (tertiary_frame_color && tertiary_frame_color.name),
      (frame_material && frame_material_name),
      frame_size,
      frame_model,
      (rear_wheel_size && "#{rear_wheel_size.name} wheel"),
      (front_wheel_size && front_wheel_size != rear_wheel_size ? "#{front_wheel_size.name} wheel" : nil),
      extra_registration_number,
      (type == "bike" ? nil : type),
      components_cache_string
    ].flatten.reject(&:blank?).join(" ")
  end

  def frame_material_name
    FrameMaterial.new(frame_material).name
  end

  def handlebar_type_name
    HandlebarType.new(handlebar_type).name
  end

  def cycle_type_name
    CycleType.new(cycle_type).name
  end

  def propulsion_type_name
    PropulsionType.new(propulsion_type).name
  end

  # Only geocode if address is set manually (and not skipping geocoding)
  def should_be_geocoded?
    return false if skip_geocoding? || !address_set_manually
    address_changed?
  end

  # Should be private. Not for now, because we're migrating (removing #stolen?, #impounded?, etc)
  def calculated_status
    return "status_impounded" if current_impound_record.present?
    return "unregistered_parking_notification" if status == "unregistered_parking_notification"
    return "status_abandoned" if abandoned? || parking_notifications.active.appears_abandoned_notification.any?
    return "status_stolen" if current_stolen_record.present?

    "status_with_owner"
  end

  private

  # Select the source from which to derive location data, in the following order
  # of precedence:
  #
  # 1. The current parking notification, if one is present
  # 2. The creation organization, if one is present
  # 3. The bike owner's address, if available
  # 4. registration_address from b_param if available
  def location_record_address_hash
    location_record = [
      current_parking_notification,
      creation_organization&.default_location,
      owner
    ].compact.find { |rec| rec.latitude.present? }
    location_record.present? ? location_record.address_hash : b_params_address
  end

  def b_params_address
    bp_address = {}
    b_params.each do |b_param|
      bp_address = b_param.fetch_formatted_address
      break if bp_address.present?
    end
    bp_address
  end
end
