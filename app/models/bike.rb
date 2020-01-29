class Bike < ApplicationRecord
  acts_as_paranoid without_default_scope: true
  include Phonifyerable
  include ActiveModel::Dirty
  include BikeSearchable
  include Geocodeable

  mount_uploader :pdf, PdfUploader
  process_in_background :pdf, CarrierWaveProcessWorker

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
  belongs_to :invoice
  belongs_to :location
  belongs_to :country
  belongs_to :current_stolen_record, class_name: "StolenRecord"
  belongs_to :creator, class_name: "User" # to be deprecated and removed
  belongs_to :creation_organization, class_name: "Organization" # to be deprecated and removed

  has_many :bike_organizations, dependent: :destroy
  has_many :organizations, through: :bike_organizations
  has_many :can_edit_claimed_bike_organizations, -> { can_edit_claimed }, class_name: "BikeOrganization"
  has_many :can_edit_claimed_organizations, through: :can_edit_claimed_bike_organizations, source: :organization
  has_many :creation_states, dependent: :destroy
  # delegate :creator, to: :creation_state, source: :creator
  # has_one :creation_organization, through: :creation_state, source: :organization
  has_many :stolen_notifications
  has_many :stolen_records
  has_many :other_listings, dependent: :destroy
  has_many :normalized_serial_segments, dependent: :destroy
  has_many :ownerships, dependent: :destroy
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :components, dependent: :destroy
  has_many :bike_stickers
  has_many :b_params, foreign_key: :created_bike_id, dependent: :destroy
  has_many :duplicate_bike_groups, through: :normalized_serial_segments
  has_many :recovered_records, -> { recovered }, class_name: "StolenRecord"
  has_many :impound_records
  has_many :abandoned_records
  has_many :current_abandoned_records, -> { current }, class_name: "AbandonedRecord"

  accepts_nested_attributes_for :stolen_records
  accepts_nested_attributes_for :components, allow_destroy: true

  validates_presence_of :serial_number
  validates_presence_of :propulsion_type
  validates_presence_of :cycle_type
  validates_presence_of :creator
  validates_presence_of :manufacturer_id

  validates_presence_of :primary_frame_color_id

  attr_accessor :other_listing_urls, :date_stolen, :receive_notifications, :has_no_serial, # has_no_serial included because legacy b_params, delete 2019-12
                :image, :b_param_id, :embeded, :embeded_extended, :paint_name,
                :bike_image_cache, :send_email, :marked_user_hidden, :marked_user_unhidden,
                :b_param_id_token, :address, :address_city, :address_state, :address_zipcode

  attr_writer :phone, :user_name, :organization_affiliation, :external_image_urls # reading is managed by a method

  enum frame_material: FrameMaterial::SLUGS
  enum handlebar_type: HandlebarType::SLUGS
  enum cycle_type: CycleType::SLUGS
  enum propulsion_type: PropulsionType::SLUGS

  default_scope {
    includes(:tertiary_frame_color, :secondary_frame_color, :primary_frame_color, :current_stolen_record)
      .current
      .order("listing_order desc")
  }
  scope :current, -> { where(example: false, hidden: false, deleted_at: nil) }
  scope :stolen, -> { where(stolen: true) }
  scope :non_stolen, -> { where(stolen: false) }
  scope :abandoned, -> { where(abandoned: true) }
  scope :organized, -> { where.not(creation_organization_id: nil) }
  scope :with_known_serial, -> { where.not(serial_number: "unknown") }
  scope :impounded, -> { includes(:impound_records).where(impound_records: { retrieved_at: nil }).where.not(impound_records: { id: nil }) }
  scope :non_abandoned, -> { where(abandoned: false) }
  # TODO: Rails 5 update - use left_joins method and the text version of enum
  scope :lightspeed_pos, -> { includes(:creation_states).where(creation_states: { pos_kind: 2 }) }
  scope :ascend_pos, -> { includes(:creation_states).where(creation_states: { pos_kind: 3 }) }
  scope :any_pos, -> { includes(:creation_states).where.not(creation_states: { pos_kind: 0 }) }
  scope :no_pos, -> { includes(:creation_states).where(creation_states: { pos_kind: 0 }) }
  scope :example, -> { where(example: true) }
  scope :non_example, -> { where(example: false) }

  before_save :set_calculated_attributes

  include PgSearch
  pg_search_scope :pg_search, against: {
                                serial_number: "A",
                                cached_data: "B",
                                all_description: "C",
                              }

  pg_search_scope :admin_search,
                  against: { owner_email: "A" },
                  associated_against: { ownerships: :owner_email, creator: :email },
                  using: { tsearch: { dictionary: "english", prefix: true } }

  class << self
    def old_attr_accessible
      (%w(manufacturer_id manufacturer_other serial_number
          serial_normalized made_without_serial additional_registration
          creation_organization_id manufacturer year thumb_path name stolen
          current_stolen_record_id abandoned frame_material cycle_type frame_model number_of_seats
          handlebar_type handlebar_type_other frame_size frame_size_number frame_size_unit
          rear_tire_narrow front_wheel_size_id rear_wheel_size_id front_tire_narrow
          primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id paint_id paint_name
          propulsion_type zipcode country_id belt_drive
          coaster_brake rear_gear_type_slug rear_gear_type_id front_gear_type_slug front_gear_type_id description owner_email
          timezone date_stolen receive_notifications phone creator creator_id image
          components_attributes b_param_id embeded embeded_extended example hidden
          stock_photo_url pdf send_email other_listing_urls listing_order approved_stolen
          marked_user_hidden marked_user_unhidden b_param_id_token is_for_sale bike_organization_ids
      ).map(&:to_sym) + [stolen_records_attributes: StolenRecord.old_attr_accessible,
                         components_attributes: Component.old_attr_accessible]).freeze
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
      if bike_str.match(/^\d+\z/) # it's only numbers, so it's a timestamp
        bike_id = bike_str
      else
        bike_id = bike_str.match(/bikes\/\d*/i)
        bike_id = bike_id && bike_id[0].gsub(/bikes./, "") || nil
      end
      where(id: bike_id).first
    end

    def bike_sticker(organization_id = nil) # This method only accepts numerical org ids
      return includes(:bike_stickers).where.not(bike_stickers: { bike_id: nil }) if organization_id.blank?
      includes(:bike_stickers).where(bike_stickers: { organization_id: organization_id })
    end

    def no_bike_sticker # This method doesn't accept org_id because Seth got lazy
      includes(:bike_stickers).where(bike_stickers: { bike_id: nil })
    end

    def organization(org_or_org_ids)
      ids = org_or_org_ids.is_a?(Organization) ? Organization.friendly_find(org_or_org_ids)&.id : org_or_org_ids
      includes(:bike_organizations).where(bike_organizations: { organization_id: ids })
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
      location = { city: city, state: state, country: country }.select { |_, v| v.present? }
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

  def cleaned_error_messages # We don't actually want to show these messages to the user, since they just tell us the bike wasn't created
    errors.full_messages.reject { |m| m[/(bike can.t be blank|are you sure the bike was created)/i] }
  end

  def calculated_listing_order
    return current_stolen_record.date_stolen.to_time.to_i.abs if stolen && current_stolen_record.present?
    t = (updated_at || Time.current).to_i / 10000
    stock_photo_url.present? || public_images.present? ? t : t / 100
  end

  def creation_state; creation_states.first end

  def creation_description; creation_state&.creation_description end

  def bulk_import; creation_state&.bulk_import end

  def pos_kind; creation_state&.pos_kind end

  def pos?; pos_kind != "no_pos" end

  def current_ownership; ownerships.reorder(:created_at).last end

  # Use present? to ensure true/false rather than nil
  def claimed?; current_ownership.present? && current_ownership.claimed.present? end

  # owner resolves to creator if user isn't present, or organization auto user. shouldn't ever be nil
  def owner; current_ownership&.owner end

  # This can be nil!
  def user; current_ownership&.user end

  def user?; user.present? end

  def stolen_recovery?; recovered_records.any? end

  def current_impound_record; impound_records.current.last end

  def impounded?; current_impound_record.present? end

  def current_initial_abandoned_record; current_abandoned_records.initial_record.first end

  # Temporary fix because of existing #abandoned attr, will be folded into enum
  def abandoned_state?; current_abandoned_records.any? end

  # Small helper because we call this a lot
  def type; cycle_type && cycle_type_name.downcase end

  def user_hidden; hidden && current_ownership&.user_hidden end

  # Currently a stub - this will be turned into an enum in the future, removing #stolen?, #impounded?, etc
  def state; calculated_state end

  def email_visible_for?(org)
    organizations.include?(org)
  end

  def serial_display
    return "Hidden" if abandoned
    return serial_number.humanize if no_serial?
    serial_number
  end

  # We may eventually remove the boolean. For now, we're just going with it.
  def made_without_serial?; made_without_serial end

  def serial_unknown?; serial_number == "unknown" end

  def no_serial?; made_without_serial? || serial_unknown? end

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

  def owner_name_or_email; owner_name || owner_email end

  def first_ownership; ownerships.reorder(:id).first end

  def organized?(org = nil)
    if org.present?
      bike_organization_ids.include?(org.id)
    else
      bike_organizations.any?
    end
  end

  # check if this is the first ownership - or if no owner, which means testing probably
  def first_ownership?; current_ownership&.blank? || current_ownership == first_ownership end

  def editable_organizations
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

  def first_owner_email; first_ownership.owner_email end

  def claimable_by?(u)
    return false if u.blank? || current_ownership.blank? || current_ownership.claimed?
    user == u || current_ownership.claimable_by?(u)
  end

  def authorized?(u)
    return true if u == owner || claimable_by?(u)
    return false if u.blank?
    authorized_by_organization?(u: u)
  end

  def authorize_and_claim_for_user(u)
    return authorized?(u) unless claimable_by?(u)
    current_ownership.mark_claimed
    true
  end

  def impound(passed_user, organization: nil)
    organization ||= passed_user.organizations.detect { |o| o.paid_for?("impound_bikes") }
    impound_record = impound_records.where(organization_id: organization&.id).first
    impound_record ||= impound_records.create(user: passed_user, organization: organization)
  end

  def bike_sticker?(organization_id = nil) # This method only accepts numerical org ids
    bike_stickers.where(organization_id.present? ? { organization_id: organization_id } : {}).any?
  end

  def display_contact_owner?(u = nil)
    stolen? && current_stolen_record.present?
  end

  def contact_owner?(u = nil, organization = nil)
    return false unless u.present?
    return true if stolen? && current_stolen_record.present?
    return false unless owner&.notification_unstolen
    return u.send_unstolen_notifications? unless organization.present? # Passed organization overrides user setting to speed stuff up
    organization.paid_for?("unstolen_notifications") && u.member_of?(organization)
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

  def visible_by(passed_user = nil)
    return true unless hidden || deleted?
    if passed_user.present?
      return true if passed_user.superuser?
      return false if deleted?
      return true if owner == passed_user && user_hidden
    end
    false
  end

  def find_current_stolen_record
    return unless stolen_records.any?
    self.current_stolen_record = stolen_records.last
  end

  def title_string
    t = [year, mnfg_name, frame_model].join(" ")
    t += " #{type}" if type != "bike"
    Rails::Html::FullSanitizer.new.sanitize(t.gsub(/\s+/, " ")).strip
  end

  def stolen_string
    return nil unless stolen and current_stolen_record.present?
    [
      "Stolen ",
      current_stolen_record.date_stolen && current_stolen_record.date_stolen.strftime("%Y-%m-%d"),
      current_stolen_record.address && "from #{current_stolen_record.address}. ",
    ].compact.join(" ")
  end

  def video_embed_src
    if video_embed.present?
      code = Nokogiri::HTML(video_embed)
      src = code.xpath("//iframe/@src")
      if src[0]
        src[0].value
      end
    end
  end

  def bike_organization_ids
    bike_organizations.pluck(:organization_id)
  end

  def bike_organization_ids=(val)
    org_ids = (val.is_a?(Array) ? val : val.split(",").map(&:strip))
      .map { |id| validated_organization_id(id) }.compact
    org_ids.each { |id| bike_organizations.where(organization_id: id).first_or_create }
    bike_organizations.each { |bo| bo.destroy unless org_ids.include?(bo.organization_id) }
    true
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
    if manufacturer.blank?
      n = ""
    elsif manufacturer.name == "Other" && manufacturer_other.present?
      n = Rails::Html::FullSanitizer.new.sanitize(manufacturer_other)
    else
      n = manufacturer.simple_name
    end
    self.mnfg_name = n.strip.truncate(60)
  end

  def set_user_hidden
    if marked_user_hidden.present? && marked_user_hidden.to_s != "0"
      self.hidden = true
      current_ownership.update_attribute :user_hidden, true unless current_ownership.user_hidden
    elsif marked_user_unhidden.present? && marked_user_unhidden.to_s != "0"
      self.hidden = false
      current_ownership.update_attribute :user_hidden, false if current_ownership.user_hidden
    end
    true
  end

  def normalize_emails
    if User.fuzzy_email_find(owner_email)
      self.owner_email = User.fuzzy_email_find(owner_email).email
    else
      self.owner_email = EmailNormalizer.normalize(owner_email)
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
      if frame_size_number.present?
        if frame_size_number < 30 # Good guessing?
          self.frame_size_unit = "in"
        else
          self.frame_size_unit = "cm"
        end
      else
        self.frame_size_unit = "ordinal"
      end
    end

    if frame_size_number.present?
      self.frame_size = frame_size_number.to_s.gsub(".0", "") + frame_size_unit
    else
      self.frame_size = case frame_size.downcase
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
                        else
                          nil
                        end
    end
    true
  end

  def set_paints
    self.paint_id = nil if paint_id.present? && paint_name.blank? && paint_name != nil
    return true unless paint_name.present?
    self.paint_name = paint_name[0] if paint_name.kind_of?(Array)
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
    registration_address["address"].present? && registration_address["city"].present?
  end

  def registration_address # Goes along with organization additional_registration_fields
    return @registration_address if defined?(@registration_address)
    if user&.address_hash&.present?
      @registration_address = user&.address_hash
    else
      @registration_address = b_params.map(&:fetch_formatted_address).reject(&:blank?).first || {}
    end
  end

  def registration_location
    address = registration_address.with_indifferent_access
    city = address[:city]&.titleize
    state = address[:state]&.upcase
    return "" if state.blank?

    [city, state].reject(&:blank?).join(", ")
  end

  def location_info_present?(record)
    return false if record.blank?

    if record.respond_to?(:country)
      record.country.present? &&
        (record.city.present? || record.zipcode.present?)
    elsif record.respond_to?(:country_code)
      record.country_code.present? &&
        (record.city.present? || record.zipcode.present?)
    end
  end

  # Set the bike's location data (lat/long, city, postal code, country)
  # in the following order of precedence:
  #
  # 1. From the current stolen record, if one is present
  # 2. From the creation organization, if one is present
  # 3. From the bike owner's address, if available
  # 4. From the request's IP address, if given
  def set_location_info(request_location: nil)
    find_current_stolen_record

    if location_info_present?(current_stolen_record)
      self.latitude = current_stolen_record.latitude
      self.longitude = current_stolen_record.longitude
      self.city = current_stolen_record.city
      self.country = current_stolen_record.country
      self.zipcode = current_stolen_record.zipcode
    elsif location_info_present?(creation_organization)
      self.latitude = creation_organization.location_latitude
      self.longitude = creation_organization.location_longitude
      self.city = creation_organization.city
      self.country = creation_organization.country
      self.zipcode = creation_organization.zipcode
    elsif location_info_present?(owner)
      self.latitude = owner.latitude
      self.longitude = owner.longitude
      self.city = owner.city
      self.country = owner.country
      self.zipcode = owner.zipcode
    elsif location_info_present?(request_location)
      self.latitude = request_location.latitude
      self.longitude = request_location.longitude
      self.city = request_location.city
      self.country = Country.fuzzy_find(request_location&.country_code)
      self.zipcode = request_location.postal_code
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
      primary_frame_color && primary_frame_color.name,
      secondary_frame_color && secondary_frame_color.name,
      tertiary_frame_color && tertiary_frame_color.name,
    ].compact
  end

  def cgroup_array # list of cgroups so that we can arrange them
    components.map(&:cgroup_id).uniq
  end

  def cache_photo
    self.thumb_path = public_images && public_images.first && public_images.first.image_url(:small)
  end

  def set_calculated_attributes
    self.listing_order = calculated_listing_order
    clean_frame_size
    set_mnfg_name
    set_user_hidden
    normalize_emails
    normalize_serial_number
    set_paints
    cache_bike
  end

  def components_cache_string
    components.all.map.each do |c|
      [
        c.year,
        (c.manufacturer && c.manufacturer.name),
        c.component_type,
      ] if c.ctype.present? && c.ctype.name.present?
    end
  end

  def cache_stolen_attributes
    csr = find_current_stolen_record
    self.current_stolen_record_id = csr&.id
    self.all_description =
      [description, csr&.theft_description]
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
      additional_registration,
      (type == "bike" ? nil : type),
      components_cache_string,
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

  # Geolocate based on the full current stolen record address, if available.
  # Otherwise, use the data set by set_location_info.
  def geocode_data
    return @geocode_data if defined?(@geocode_data)

    # Sets lat/long, will avoid a geocode API call if coordinates are found
    set_location_info

    @geocode_data =
      current_stolen_record
        &.address(override_show_address: true)
        .presence ||
      [city, zipcode, country&.name]
        .select(&:present?)
        .join(" ")
        .presence
  end

  # Take lat/long from associated geocoded model
  # Only geocode if no lat/long present and geocode data present
  def should_be_geocoded?
    return false if skip_geocoding?
    return false if latitude.present? && longitude.present?
    geocode_data.present?
  end

  private

  def calculated_state
    return "stolen" if current_stolen_record.present?
    return "impounded" if current_impound_record.present?
    return "abandoned" if current_abandoned_records.any?
    "with_owner"
  end
end
