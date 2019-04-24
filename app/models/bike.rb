class Bike < ActiveRecord::Base
  include ActiveModel::Dirty
  include BikeSearchable
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
  belongs_to :current_stolen_record, class_name: "StolenRecord"
  belongs_to :creator, class_name: "User" # to be deprecated and removed
  belongs_to :creation_organization, class_name: "Organization" # to be deprecated and removed

  has_many :bike_organizations, dependent: :destroy
  has_many :organizations, through: :bike_organizations
  has_many :creation_states, dependent: :destroy
  # delegate :creator, to: :creation_state, source: :creator
  # has_one :creation_organization, through: :creation_state, source: :organization
  has_many :stolen_notifications, dependent: :destroy
  has_many :stolen_records, dependent: :destroy
  has_many :other_listings, dependent: :destroy
  has_many :normalized_serial_segments, dependent: :destroy
  has_many :ownerships, dependent: :destroy
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :components, dependent: :destroy
  has_many :bike_codes
  has_many :b_params, foreign_key: :created_bike_id, dependent: :destroy
  has_many :duplicate_bike_groups, through: :normalized_serial_segments
  has_many :recovered_records, -> { recovered }, class_name: "StolenRecord"

  accepts_nested_attributes_for :stolen_records
  accepts_nested_attributes_for :components, allow_destroy: true

  geocoded_by nil, latitude: :stolen_lat, longitude: :stolen_long
  after_validation :geocode, if: lambda { |o| false } # Never geocode, it's from stolen_record

  validates_presence_of :serial_number
  validates_presence_of :propulsion_type
  validates_presence_of :cycle_type
  validates_presence_of :creator
  validates_presence_of :manufacturer_id

  validates_uniqueness_of :card_id, allow_nil: true
  validates_presence_of :primary_frame_color_id

  attr_accessor :other_listing_urls, :date_stolen, :receive_notifications,
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
      .where(example: false, hidden: false)
      .order("listing_order desc")
  }
  scope :stolen, -> { where(stolen: true) }
  scope :non_stolen, -> { where(stolen: false) }
  scope :organized, -> { where.not(creation_organization_id: nil) }
  scope :with_serial, -> { where("serial_number != ?", "absent") }
  # "Recovered" bikes are bikes that were found and are waiting to be claimed. This is confusing and should be fixed
  # so that it no longer is the same word as stolen recoveries
  scope :non_recovered, -> { where(recovered: false) }
  # TODO: Rails 5 update - use left_joins method and the text version of enum
  scope :lightspeed_pos, -> { includes(:creation_states).where(creation_states: { pos_kind: 2 }) }
  scope :ascend_pos, -> { includes(:creation_states).where(creation_states: { pos_kind: 3 }) }

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
      # made_without_serial - GUARANTEE there was no serial
      (%w(manufacturer_id manufacturer_other serial_number
          serial_normalized has_no_serial made_without_serial additional_registration
          creation_organization_id manufacturer year thumb_path name stolen
          current_stolen_record_id recovered frame_material cycle_type frame_model number_of_seats
          handlebar_type frame_size frame_size_number frame_size_unit
          rear_tire_narrow front_wheel_size_id rear_wheel_size_id front_tire_narrow
          primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id paint_id paint_name
          propulsion_type zipcode country_id belt_drive
          coaster_brake rear_gear_type_slug rear_gear_type_id front_gear_type_slug front_gear_type_id description owner_email
          timezone date_stolen receive_notifications phone creator creator_id image
          components_attributes b_param_id embeded embeded_extended example hidden
          card_id stock_photo_url pdf send_email other_listing_urls listing_order approved_stolen
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
  end

  def cleaned_error_messages # We don't actually want to show these messages to the user, since they just tell us the bike wasn't created
    errors.full_messages.reject { |m| m[/(bike can.t be blank|are you sure the bike was created)/i] }
  end

  def get_listing_order
    return current_stolen_record.date_stolen.to_time.to_i.abs if stolen && current_stolen_record.present?
    t = (updated_at || Time.now).to_i / 10000
    stock_photo_url.present? || public_images.present? ? t : t / 100
  end

  def creation_state; creation_states.first end

  def creation_description; creation_state&.creation_description end

  def bulk_import; creation_state&.bulk_import end

  def pos_kind; creation_state&.pos_kind end

  def pos?; pos_kind != "not_pos" end

  def current_ownership; ownerships.reorder(:created_at).last end

  # Use present? to ensure true/false rather than nil
  def claimed?; current_ownership.present? && current_ownership.claimed.present? end

  # owner resolves to creator if user isn't present, or organization auto user. shouldn't ever be nil
  def owner; current_ownership && current_ownership.owner end

  # This can be nil!
  def user; current_ownership&.user end

  def user?; user.present? end

  def stolen_recovery?; recovered_records.any? end

  # Small helper because we call this a lot
  def type; cycle_type && cycle_type_name.downcase end

  # this should be put somewhere else sometime
  def serial; serial_number unless recovered end

  def user_hidden; hidden && current_ownership&.user_hidden end

  def fake_deleted; hidden && !user_hidden end

  # This is for organizations - might be useful for admin as well. We want it to be nil if it isn't present
  # User - not ownership, because we don't want registrar
  def user_name
    return user.name if user&.name.present?
    # Only grab the name from b_params if it's the first owner - or if no owner, which means testing probably
    return nil unless current_ownership.blank? || current_ownership&.first?
    b_params.map(&:user_name).reject(&:blank?).first
  end

  def user_name_or_email; user_name || owner_email end

  def first_ownership; ownerships.reorder(:id).first end

  def organized?(org = nil)
    org.present? ? bike_organization_ids.include?(org.id) : bike_organizations.any?
  end

  # check if this is the first ownership - or if no owner, which means testing probably
  def first_ownership?; current_ownership&.blank? || current_ownership == first_ownership end

  def authorized_by_organization?(u: nil, org: nil)
    return false unless first_ownership? && organized? && !claimed?
    return true unless u.present? || org.present?
    return creation_organization == org if org.present? && u.blank?
    # so, we know a user was passed
    return false if claimable_by?(u) # this is authorized by owner, not organization
    return organizations.any? { |o| u.member_of?(o) } unless org.present?
    creation_organization == org && u.member_of?(org)
  end

  def first_owner_email; first_ownership.owner_email end

  def claimable_by?(u)
    return false if u.blank? || current_ownership.blank? || current_ownership.claimed?
    user == u || current_ownership.claimable_by?(u)
  end

  def authorize_for_user(u)
    return true if u == owner || claimable_by?(u)
    return false if u.blank? || current_ownership&.claimed
    authorized_by_organization?(u: u)
  end

  def authorize_for_user!(u)
    return authorize_for_user(u) unless claimable_by?(u)
    current_ownership.mark_claimed
    true
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
    @phone ||= user&.phone
    # Only grab the phone number from b_params if this is the first_ownership
    if first_ownership?
      @phone ||= b_params.map(&:phone).reject(&:blank?).first
    end
    @phone
  end

  def visible_by(passed_user = nil)
    return true unless hidden
    if passed_user.present?
      return true if passed_user.superuser
      return true if owner == passed_user && user_hidden
    end
    false
  end

  def find_current_stolen_record
    stolen_records.last if stolen_records.any?
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
    msg = organization ? "suspended and can't be used" : "not found"
    errors.add(:organization, "#{organization_id} is #{msg}")
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

  def normalize_attributes
    self.serial_number = "absent" if serial_number.blank? || serial_number.strip.downcase == "unknown"
    self.serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
    if User.fuzzy_email_find(owner_email)
      self.owner_email = User.fuzzy_email_find(owner_email).email
    else
      self.owner_email = EmailNormalizer.normalize(owner_email)
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

  def registration_address # Goes along with organization additional_registration_fields
    @registration_address ||= b_params.map(&:fetch_formatted_address).reject(&:blank?).first || {}
  end

  def organization_affiliation
    b_params.map { |bp| bp.organization_affiliation }.compact.join(", ")
  end

  def external_image_urls
    b_params.map { |bp| bp.external_image_urls }.flatten.reject(&:blank?).uniq
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
    self.listing_order = get_listing_order
    clean_frame_size
    set_mnfg_name
    set_user_hidden
    normalize_attributes
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
    self.attributes = {
      current_stolen_record_id: csr && csr.id,
      all_description: [description, csr && csr.theft_description].reject(&:blank?).join(" "),
      stolen_lat: csr && csr.latitude,
      stolen_long: csr && csr.longitude,
    }
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
end
