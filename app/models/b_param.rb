# b_param stands for Bike param
class BParam < ActiveRecord::Base
  mount_uploader :image, ImageUploader
  store_in_background :image, CarrierWaveStoreWorker

  # serialize :params
  serialize :bike_errors

  belongs_to :created_bike, class_name: 'Bike'
  belongs_to :creator, class_name: 'User'
  belongs_to :organization

  scope :with_bike, -> { where('created_bike_id IS NOT NULL') }
  scope :without_bike, -> { where(created_bike_id: nil) }
  scope :without_creator, -> { where(creator_id: nil) }
  scope :partial_registrations, -> { where(origin: "embed_partial") }

  before_create :generate_id_token
  before_save :clean_params

  def self.v2_params(hash)
    h = hash['bike'].present? ? hash : { 'bike' => hash.with_indifferent_access }
    h['bike']['serial_number'] = h['bike'].delete 'serial'
    h['bike']['send_email'] = !(h['bike'].delete 'no_notify')
    org = Organization.friendly_find(h['bike'].delete 'organization_slug')
    h['bike']['creation_organization_id'] = org.id if org.present?
    # Move un-nested params outside of bike
    %w(test id components).each { |k| h[k] = h['bike'].delete k }
    stolen_attrs = h['bike'].delete 'stolen_record'
    if stolen_attrs && stolen_attrs.delete_if { |k,v| v.blank? } && stolen_attrs.keys.any?
      h['bike']['stolen'] = true
      h['stolen_record'] = stolen_attrs
    end
    h
  end

  def self.find_or_new_from_token(toke = nil, user_id: nil, organization_id: nil)
    b = where(creator_id: user_id, id_token: toke).first if toke.present? && user_id.present?
    b ||= with_organization_or_no_creator(toke)
    b ||= BParam.new(creator_id: user_id, params: { revised_new: true }.as_json)
    b.creator_id ||= user_id
    # If the org_id is present, add it to the params. Only save it if the b_param is created_at
    if organization_id.present? && b.creation_organization_id != organization_id
      b.params = b.params.merge(bike: b.bike.merge(creation_organization_id: organization_id))
      b.update_attribute :params, b.params if b.id.present?
    end
    # Assign the correct user if user is part of the org (for embed submissions)
    if b.creation_organization_id.present? && b.creator_id != user_id
      if Membership.where(user_id: user_id, organization_id: b.creation_organization_id).present?
        b.update_attribute :creator_id, user_id
      end
    end
    b
  end

  def self.with_organization_or_no_creator(toke) # Because organization embed bikes might not match the creator
    without_bike.where('created_at >= ?', Time.now - 1.month).where(id_token: toke)
      .detect { |b| b.creator_id.blank? || b.creation_organization_id.present? || b.params['creation_organization_id'].present? }
  end

  def self.assignable_attrs
    %w(manufacturer_id manufacturer_other frame_model year owner_email creation_organization_id
       stolen recovered serial_number has_no_serial made_without_serial
       primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id)
  end

  def self.skipped_bike_attrs # Attrs that need to be skipped on bike assignment
    %w(cycle_type_slug cycle_type_name rear_gear_type_slug front_gear_type_slug bike_code address
       handlebar_type_slug is_bulk is_new is_pos no_duplicate)
  end

  def self.email_search(str)
    return all unless str.present?
    where("email ilike ?", "%#{str.strip}%")
  end

  # Crazy new shit
  def manufacturer_id=(val)
    params['bike']['manufacturer_id'] = val
  end

  def creation_organization_id=(val)
    params['bike']['creation_organization_id'] = val
  end

  def owner_email=(val)
    params['bike']['owner_email'] = val
  end

  def stolen=(val)
    params['bike']['stolen'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(val)
  end

  def primary_frame_color_id=(val)
    params['bike']['primary_frame_color_id'] = val
  end
  def secondary_frame_color_id=(val)
    params['bike']['secondary_frame_color_id'] = val
  end
  def tertiary_frame_color_id=(val)
    params['bike']['tertiary_frame_color_id'] = val
  end

  def with_bike?; created_bike_id.present? end
  def bike; (params && params['bike'] || {}).with_indifferent_access end
  def primary_frame_color_id; bike['primary_frame_color_id'] end
  def secondary_frame_color_id; bike['secondary_frame_color_id'] end
  def tertiary_frame_color_id; bike['tertiary_frame_color_id'] end
  def manufacturer_id; bike['manufacturer_id'] end
  def stolen; bike['stolen'] end
  def is_pos; bike['is_pos'] || false end
  def is_new; bike['is_new'] || false end
  def is_bulk; bike['is_bulk'] || false end
  def no_duplicate; bike['no_duplicate'] || false end
  def bike_code; bike["bike_code"] end
  def phone; bike["phone"] end
  def user_name; bike["user_name"] end

  def creation_organization; Organization.friendly_find(creation_organization_id) end
  def manufacturer; bike['manufacturer_id'] && Manufacturer.friendly_find(bike['manufacturer_id']) end
  def partial_registration?; origin == "embed_partial" end
  def primary_frame_color; primary_frame_color_id.present? && Color.find(primary_frame_color_id)&.name end

  # Right now this is a partial update. It's improved from where it was, but it still uses the BikeCreator
  # code for protection. Ideally, we would use the revised merge code to ensure we aren't letting users
  # write illegal things to the bikes
  def clean_params(updated_params = {}) # So we can pass in the params
    self.params ||= { bike: {} } # ensure valid json object
    self.params = params.with_indifferent_access.deep_merge(updated_params.with_indifferent_access)
    massage_if_v2
    set_foreign_keys
    self.organization_id = creation_organization_id
    self.email = owner_email
    self
  end

  def massage_if_v2
    self.params = self.class.v2_params(params) if origin == 'api_v2'
    true
  end

  def set_foreign_keys
    return true unless params.present? && bike.present?
    bike['stolen'] = true if params['stolen_record'].present?
    set_wheel_size_key
    set_manufacturer_key
    set_color_key unless bike['primary_frame_color_id'].present?
    set_cycle_type_key 
    set_rear_gear_type_slug if bike['rear_gear_type_slug'].present?
    set_front_gear_type_slug if bike['front_gear_type_slug'].present?
    set_handlebar_type_key 
    set_frame_material_key # Even if the value isn't present, since we need to remove the key
  end

  def set_handlebar_type_key
    key = bike['handlebar_type'] || bike['handlebar_type_slug']
    ht = HandlebarType.friendly_find(key)
    params['bike']['handlebar_type'] = ht&.slug
    params['bike'].delete('handlebar_type_slug')
  end

  def set_cycle_type_key
    if key = (bike['cycle_type'] || bike['cycle_type_slug'] || bike['cycle_type_name']).presence
      ct = CycleType.friendly_find(key)
      params['bike']['cycle_type'] = ct&.slug
      params['bike'].delete('cycle_type_slug')
      params['bike'].delete('cycle_type_name')
    end
  end

  def set_wheel_size_key
    if bike.keys.include?('rear_wheel_bsd')
      key = '_wheel_bsd'
    elsif bike['rear_wheel_size'].present?
      key = '_wheel_size'
    else
      return nil
    end
    rbsd = params['bike'].delete("rear#{key}")
    fbsd = params['bike'].delete("front#{key}")
    params['bike']['rear_wheel_size_id'] = WheelSize.id_for_bsd(rbsd)
    params['bike']['front_wheel_size_id'] = WheelSize.id_for_bsd(fbsd)
  end

  def set_frame_material_key
    frame_material = FrameMaterial.friendly_find(bike["frame_material_slug"])
    params["bike"]["frame_material"] = frame_material.slug if frame_material.present?
    params["bike"].delete("frame_material_slug")
  end

  def set_manufacturer_key
    return false unless bike.present?
    m = params['bike'].delete('manufacturer')
    m = params['bike'].delete('manufacturer_id') unless m.present?
    return nil unless m.present?
    b_manufacturer = Manufacturer.friendly_find(m)
    unless b_manufacturer.present?
      b_manufacturer = Manufacturer.other
      params['bike']['manufacturer_other'] = m
    end
    params['bike']['manufacturer_id'] = b_manufacturer.id
  end

  def set_rear_gear_type_slug
    gear = RearGearType.where(slug: params['bike'].delete('rear_gear_type_slug')).first
    params['bike']['rear_gear_type_id'] = gear && gear.id
  end

  def set_front_gear_type_slug
    gear = FrontGearType.where(slug: params['bike'].delete('front_gear_type_slug')).first
    params['bike']['front_gear_type_id'] = gear && gear.id
  end

  def set_color_key
    paint = params['bike']['color']
    color = Color.friendly_find(paint.strip) if paint.present?
    if color.present?
      params['bike']['primary_frame_color_id'] = color.id
    else
      set_paint_key(paint)
    end
    params['bike'].delete('color')
  end

  def set_paint_key(paint_entry)
    return nil unless paint_entry.present?
    paint = Paint.friendly_find(paint_entry)
    if paint.present?
      params['bike']['paint_id'] = paint.id
    else
      paint = Paint.new(name: paint_entry)
      paint.manufacturer_id = bike['manufacturer_id'] if is_pos
      paint.save
      params['bike']['paint_id'] = paint.id
      params['bike']['paint_name'] = paint.name
    end
    unless bike['primary_frame_color_id'].present?
      if paint.color_id.present?
        params['bike']['primary_frame_color_id'] = paint.color.id
      else
        params['bike']['primary_frame_color_id'] = Color.find_by_name('Black').id
      end
    end
  end

  def find_duplicate_bike(bike)
    return nil unless no_duplicate
    dupe = Bike.where(serial_number: bike.serial_number, owner_email: bike.owner_email)
            .where.not(id: bike.id).order(:created_at).first
    return nil unless dupe.present?
    self.update_attribute :created_bike_id, dupe.id
  end

  def mnfg_name
    return nil unless manufacturer.present?
    if manufacturer.other? && bike["manufacturer_other"].present?
      Rails::Html::FullSanitizer.new.sanitize(bike["manufacturer_other"].to_s)
    else
      manufacturer.simple_name
    end.strip.truncate(60)
  end

  def generate_id_token
    self.id_token ||= generate_unique_token
  end

  # Below here is revised setup, an attempt to make the process of upgrading rails easier
  # by reducing reliance on attr_accessor, and also not creating b_params unless we need to
  # To protect organization registration and other non-user-set options in revised setup,
  # Set the protected attrs separately from the params hash and merging over the passed params
  # Now that we're on rails 4, this is just a giant headache.
  def bike_from_attrs(is_stolen: nil, recovered: nil)
    is_stolen = params['bike']['stolen'] if params['bike'] && params['bike'].keys.include?('stolen')
    Bike.new(safe_bike_attrs({ 'stolen' => is_stolen, 'recovered' => recovered }).as_json)
  end

  def safe_bike_attrs(param_overrides)
    bike.merge(param_overrides).select { |k, v| self.class.assignable_attrs.include?(k.to_s) }
        .merge('b_param_id' => id,
               'creator_id' => creator_id)
  end

  def revised_new?
    params && params['revised_new']
  end

  def creation_organization_id
    bike && bike["creation_organization_id"] || params && params["creation_organization_id"]
  end

  def owner_email
    bike && bike['owner_email']
  end

  def display_email? # For revised form. If there aren't errors and there is an email, then we don't need to show
    true unless owner_email.present? && bike_errors.blank?
  end

  def fetch_formatted_address
    return {} unless bike["address"].present?
    return params["formatted_address"] if params["formatted_address"].present?
    formatted_address = Geohelper.formatted_address_hash(bike["address"])
    return {} unless formatted_address.present?
    update_attribute :params, params.merge(formatted_address: formatted_address)
    formatted_address
  end

  protected

  def generate_unique_token
    begin
      toke = SecureRandom.urlsafe_base64
    end while BParam.where(id_token: toke).exists?
    toke
  end
end
