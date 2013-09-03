class Bike < ActiveRecord::Base  
  include ActiveModel::Dirty
  attr_accessible :verified,
    :payment_required,
    :paid_for,
    :cycle_type_id,
    :manufacturer_id, 
    :manufacturer_other,
    :serial_number,
    :has_no_serial,
    :creation_organization_id,
    :location_id,
    :manufacturer,
    :frame_manufacture_year,
    :thumb_path,
    :name, 
    :stolen,
    :frame_material_id, 
    :frame_material_other,
    :frame_model, 
    :handlebar_type_id,
    :handlebar_type_other,
    :seat_tube_length,
    :seat_tube_length_in_cm,  
    :rear_tire_narrow,
    :front_wheel_size_id,
    :rear_wheel_size_id,
    :front_tire_narrow,
    :number_of_seats, 
    :primary_frame_color_id,
    :secondary_frame_color_id,
    :tertiary_frame_color_id,
    :propulsion_type_id,
    :propulsion_type_other,
    :zipcode,
    :rear_gear_type_id,
    :rear_gear_type_other,
    :front_gear_type_id,
    :front_gear_type_other,
    :description,
    :owner_email,
    :stolen_records_attributes,
    :date_stolen_input,
    :phone,
    :creator,
    :creator_id,
    :created_with_token,
    :bike_image,
    :components_attributes,
    :bike_token_id,
    :b_param_id,
    :cached_attributes

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
  belongs_to :creator, class_name: "User"
  belongs_to :invoice
  belongs_to :creation_organization, class_name: "Organization"
  belongs_to :location

  has_many :stolen_notifications, dependent: :destroy
  has_many :stolen_records
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
  
  # Comment below validations out when you first push to server
  validates_presence_of :primary_frame_color_id
  validates_presence_of :rear_wheel_size_id
  validates_inclusion_of :rear_tire_narrow, :in => [true, false]

  attr_accessor :date_stolen_input, :phone, :bike_image, :bike_token_id, :b_param_id, :payment_required

  default_scope order("created_at desc")
  scope :non_token, where(created_with_token: nil)
  scope :stolen, where(stolen: true)
  scope :non_stolen, where(stolen: false)

  include PgSearch
  # TODO: match serial numbers search across common substitutions,
  # i.e. 0 & O
  pg_search_scope :search, against: {
    :serial_number => 'A',
    :cached_data => 'B',
    :description => 'c',
    },
    using: {tsearch: {dictionary: "english", :prefix => true}}

  def self.text_search(query)
    if query.present?
      search(query)
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

  def current_ownership
    ownerships.last
  end

  def owner
    current_ownership.owner
  end

  def current_stolen_record
    self.stolen_records.last if self.stolen_records.any?
  end

  def manufacturer_name
    if self.manufacturer.name == "Other" && self.manufacturer_other.present?
      self.manufacturer_other
    else
      self.manufacturer.name 
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

  def type
    # Small helper because we call this a lot
    self.cycle_type.name.downcase
  end

  def cache_photo
    if self.public_images.any?
      self.thumb_path = self.public_images.first.image_url(:small)
    end
  end

  def components_cache_string
    string = ""
    components.all.each do |c|
      string += "#{c.year} " if c.manufacturer
      string += "#{c.manufacturer.name} " if c.manufacturer
      string += "#{c.component_type} "
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
    ca << "#{front_wheel_size.priority}w#{front_wheel_size_id}" if front_wheel_size_id
    self.cached_attributes = ca 
  end

  before_save :cache_bike
  def cache_bike
    cache_photo
    cache_attributes
    c = ""
    c += "#{propulsion_type.name} " unless propulsion_type.name == "Foot pedal"
    c += "#{frame_manufacture_year} " if frame_manufacture_year
    c += "#{primary_frame_color.name} " if primary_frame_color
    c += "#{secondary_frame_color.name} " if secondary_frame_color
    c += "#{tertiary_frame_color.name} " if tertiary_frame_color
    c += "#{frame_material.name} " if frame_material
    c += "#{frame_model} " if frame_model
    c += "#{manufacturer_name} "
    c += "#{type} " unless self.type == "bike"
    c += components_cache_string if components_cache_string

    self.cached_data = c
  end

end
