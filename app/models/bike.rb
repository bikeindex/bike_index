class Bike < ActiveRecord::Base
  include ActiveModel::Dirty
  include ActionView::Helpers::SanitizeHelper
  attr_accessible :verified,
    :payment_required,
    :paid_for,
    :registered_new, # Was this bike registered at point of sale?
    :cycle_type_id,
    :manufacturer_id, 
    :manufacturer_other,
    :serial_number,
    :serial_normalized,
    :has_no_serial,
    :additional_registration,
    :creation_organization_id,
    :location_id,
    :manufacturer,
    :year,
    :thumb_path,
    :name,
    :stolen,
    :current_stolen_record_id,
    :recovered,
    :frame_material_id, 
    :frame_model, 
    :handlebar_type_id,
    :handlebar_type_other,
    :frame_size,
    :frame_size_number,
    :frame_size_unit,
    :rear_tire_narrow,
    :front_wheel_size_id,
    :rear_wheel_size_id,
    :front_tire_narrow,
    :number_of_seats, 
    :primary_frame_color_id,
    :secondary_frame_color_id,
    :tertiary_frame_color_id,
    :paint_id,
    :paint_name,
    :propulsion_type_id,
    :propulsion_type_other,
    :zipcode,
    :country_id,
    :creation_zipcode,
    :belt_drive,
    :coaster_brake,
    :rear_gear_type_id,
    :front_gear_type_id,
    :description,
    :owner_email,
    :stolen_records_attributes,
    :date_stolen_input,
    :receive_notifications,
    :phone,
    :creator,
    :creator_id,
    :created_with_token,
    :image,
    :components_attributes,
    :bike_token_id,
    :b_param_id,
    :cached_attributes,
    :embeded,
    :embeded_extended,
    :example,
    :hidden,
    :card_id,
    :stock_photo_url,
    :pdf,
    :send_email,
    :other_listing_urls,
    :listing_order,
    :approved_stolen, 
    :marked_user_hidden,
    :marked_user_unhidden,
    :b_param_id_token

  mount_uploader :pdf, PdfUploader
  process_in_background :pdf, CarrierWaveProcessWorker

  belongs_to :manufacturer
  serialize(:cached_attributes, Array)
  belongs_to :primary_frame_color, class_name: "Color"
  belongs_to :secondary_frame_color, class_name: "Color"
  belongs_to :tertiary_frame_color, class_name: "Color"
  belongs_to :handlebar_type
  belongs_to :rear_wheel_size, class_name: "WheelSize"
  belongs_to :front_wheel_size, class_name: "WheelSize"
  belongs_to :rear_gear_type
  belongs_to :front_gear_type
  belongs_to :frame_material
  belongs_to :propulsion_type
  belongs_to :cycle_type
  belongs_to :paint, counter_cache: true
  belongs_to :creator, class_name: "User"
  belongs_to :updator, class_name: "User"
  belongs_to :invoice
  belongs_to :creation_organization, class_name: "Organization"
  belongs_to :location
  belongs_to :current_stolen_record, class_name: "StolenRecord"

  has_many :stolen_notifications, dependent: :destroy
  has_many :stolen_records, dependent: :destroy
  has_many :other_listings
  has_many :normalized_serial_segments
  has_many :ownerships, dependent: :destroy
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :components, dependent: :destroy
  has_many :b_params, as: :created_bike
  
  accepts_nested_attributes_for :stolen_records
  accepts_nested_attributes_for :components, allow_destroy: true

  validates_presence_of :serial_number
  # Serial numbers aren't guaranteed to be unique across manufacturers.
  # But we do want to prevent the same bike being registered multiple times...
  # validates_uniqueness_of :serial_number, message: "has already been taken. If you believe that this message is an error, contact us!"
  validates_presence_of :propulsion_type_id
  validates_presence_of :cycle_type_id
  validates_presence_of :creator
  validates_presence_of :manufacturer_id
  
  validates_uniqueness_of :card_id, allow_nil: true
  validates_presence_of :primary_frame_color_id
  # validates_presence_of :rear_wheel_size_id
  # validates_inclusion_of :rear_tire_narrow, in: [true, false]

  attr_accessor :other_listing_urls, :date_stolen_input, :receive_notifications,
    :phone, :image, :bike_token_id, :b_param_id, :payment_required, :embeded,
    :embeded_extended, :paint_name, :bike_image_cache, :send_email,
    :marked_user_hidden, :marked_user_unhidden, :b_param_id_token

  default_scope where(example: false).where(hidden: false).order("listing_order desc")
  scope :stolen, where(stolen: true)
  scope :non_stolen, where(stolen: false)

  include PgSearch
  pg_search_scope :search, against: {
    serial_number: 'A',
    cached_data:   'B',
    all_description:   'C'
  },
  using: {tsearch: {dictionary: "english", prefix: true}}

  pg_search_scope :admin_search,
    against: { owner_email: 'A' },
    associated_against: {ownerships: :owner_email, creator: :email},
    using: {tsearch: {dictionary: "english", prefix: true}}

  def self.text_search(query)
    if query.present?
      search(query)
    else
      scoped
    end
  end

  def self.admin_text_search(query)
    if query.present?
      admin_search(query)
    else
      scoped
    end
  end

  def self.attr_cache_search(query)
    return scoped unless query.present? and query.is_a? Array
    a = []
    self.find_each do |b|
      a << b.id if (query - b.cached_attributes).empty?
    end
    self.where(id: a)
  end

  def get_listing_order
    return current_stolen_record.date_stolen.to_time.to_i.abs if stolen && current_stolen_record.present?
    t = updated_at.to_time.to_i/10000
    t = t/100 unless stock_photo_url.present? or public_images.present?
    t
  end

  def current_ownership
    ownerships && ownerships.last
  end

  def owner
    current_ownership && current_ownership.owner
  end

  def user_hidden
    hidden && current_ownership && current_ownership.user_hidden
  end

  def visible_by(user=nil)
    return true unless hidden
    if user.present?
      return true if user.superuser
      return true if owner == user && user_hidden
    end
    false
  end

  def find_current_stolen_record
    self.stolen_records.last if self.stolen_records.any?
  end

  def recovered_records
    StolenRecord.recovered.where(id: self.id)
  end

  def title_string
    t = [year, manufacturer_name, frame_model].join(' ')
    t += " #{type}" if type != "bike"
    strip_tags(t.gsub(/\s+/,' ')).strip
  end

  def manufacturer_name
    if manufacturer.name == "Other" && self.manufacturer_other.present?
      manufacturer_other
    else
      manufacturer.name.gsub(/\s?\([^\)]*\)/i,'')
    end
  end

  def video_embed_src
    if video_embed.present?
      code = Nokogiri::HTML(video_embed)
      src = code.xpath('//iframe/@src')
      if src[0]
        src[0].value
      end
    end
  end

  before_save :set_mnfg_name
  def set_mnfg_name
    if manufacturer.name == "Other" && manufacturer_other.present?
      name = ActionController::Base.helpers.strip_tags(manufacturer_other)
    else
      name = manufacturer.name.gsub(/\s?\([^\)]*\)/i,'')
    end
    self.mnfg_name = name.strip
  end

  before_save :set_user_hidden
  def set_user_hidden
    if marked_user_hidden.present? && marked_user_hidden.to_s != '0'
      self.hidden = true
      current_ownership.update_attribute :user_hidden, true unless current_ownership.user_hidden
    elsif marked_user_unhidden.present? && marked_user_unhidden.to_s != '0'
      self.hidden = false
      current_ownership.update_attribute :user_hidden, false if current_ownership.user_hidden 
    end
    true
  end

  before_save :set_normalized_serial
  def set_normalized_serial
    self.serial_normalized = SerialNormalizer.new({serial: serial_number}).normalized
  end

  before_save :clean_frame_size
  def clean_frame_size 
    return true unless frame_size.present? || frame_size_number.present?
    if frame_size.present? && frame_size.match(/\d+\.?\d*/).present?
      self.frame_size_number = frame_size.match(/\d+\.?\d*/)[0].to_f
    end
    
    unless frame_size_unit.present?
      if frame_size_number.present?
        if frame_size_number < 30 # Good guessing?
          self.frame_size_unit = 'in'
        else
          self.frame_size_unit = 'cm'
        end
      else
        self.frame_size_unit = 'ordinal'
      end
    end

    if frame_size_number.present?
      self.frame_size = frame_size_number.to_s.gsub('.0','') + frame_size_unit
    else
      self.frame_size = case frame_size.downcase
      when /x*sma/, 'xs'
        'xs'
      when /sma/, 's'
        's'
      when /med/, 'm'
        'm'
      when /(lg)|(large)/, 'l'
        'l'
      when /x*l/, 'xl'
        'xl'
      else 
        nil
      end
    end
    true
  end

  def serial
    serial_number unless self.recovered
  end

  before_save :set_paints
  def set_paints
    self.paint_id = nil if paint_id.present? && paint_name.blank? && paint_name != nil
    return true unless paint_name.present?
    self.paint_name = paint_name[0] if paint_name.kind_of?(Array)
    return true if Color.fuzzy_name_find(paint_name).present?
    paint = Paint.fuzzy_name_find(paint_name)
    paint = Paint.create(name: paint_name) unless paint.present?
    self.paint_id = paint.id
  end

  def paint_description
    paint.name.titleize if self.paint.present?
  end

  def frame_colors
    c = [primary_frame_color.name]
    c << secondary_frame_color.name if secondary_frame_color
    c << tertiary_frame_color.name if tertiary_frame_color
    c
  end

  def type
    # Small helper because we call this a lot
    self.cycle_type.name.downcase
  end

  def cgroup_array
    # list of cgroups so that we can arrange them. Future feature.
    return nil unless components.any?
    a = []
    components.each { |i| a << i.cgroup_id }
    a.uniq
  end

  def cache_photo
    if self.public_images.any?
      self.thumb_path = self.public_images.first.image_url(:small)
    end
  end

  def components_cache_string
    string = ""
    components.all.each do |c|
      if c.ctype.present? && c.ctype.name.present?
        string += "#{c.year} " if c.manufacturer
        string += "#{c.manufacturer.name} " if c.manufacturer
        string += "#{c.component_type} "
      end
    end
    string
  end

  def cache_attributes
    ca = []
    ca << "#{primary_frame_color.priority}c#{primary_frame_color_id}" if primary_frame_color_id
    ca << "#{secondary_frame_color.priority}c#{secondary_frame_color_id}" if secondary_frame_color_id
    ca << "#{tertiary_frame_color.priority}c#{tertiary_frame_color_id}" if tertiary_frame_color_id
    ca << "h#{handlebar_type_id}" if handlebar_type
    ca << "#{rear_wheel_size.priority}w#{rear_wheel_size_id}" if rear_wheel_size_id
    ca << "#{front_wheel_size.priority}w#{front_wheel_size_id}" if front_wheel_size_id && front_wheel_size != rear_wheel_size
    self.cached_attributes = ca 
  end

  def cache_stolen_attributes
    d = description
    csr = find_current_stolen_record
    if csr.present?
      self.current_stolen_record_id = csr.id 
      d = "#{d} #{csr.theft_description}"
    else
      self.current_stolen_record_id = nil
    end
    self.all_description = d
  end

  before_save :cache_bike
  def cache_bike
    cache_stolen_attributes
    cache_photo
    cache_attributes
    c = ""
    c += "#{manufacturer_name} "
    c += "#{propulsion_type.name} " unless propulsion_type.name == "Foot pedal"
    c += "#{year} " if year
    c += "#{primary_frame_color.name} " if primary_frame_color
    c += "#{secondary_frame_color.name} " if secondary_frame_color
    c += "#{tertiary_frame_color.name} " if tertiary_frame_color
    c += "#{frame_material.name} " if frame_material
    c += "#{frame_size} " if frame_size
    c += "#{frame_model} " if frame_model
    c += "#{rear_wheel_size.name} wheel " if rear_wheel_size
    c += "#{front_wheel_size.name} wheel " if front_wheel_size && front_wheel_size != rear_wheel_size
    c += "#{additional_registration} "
    c += "#{type} " unless self.type == "bike"
    c += components_cache_string if components_cache_string
    self.cached_data = c
  end

end
