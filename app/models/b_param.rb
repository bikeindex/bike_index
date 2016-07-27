# b_param stands for Bike param
class BParam < ActiveRecord::Base
  attr_accessor :api_v2

  mount_uploader :image, ImageUploader
  store_in_background :image, CarrierWaveStoreWorker

  # serialize :params
  serialize :bike_errors

  belongs_to :created_bike, class_name: "Bike"
  belongs_to :creator, class_name: "User"

  scope :with_bike, -> { where('created_bike_id IS NOT NULL') }
  scope :without_bike, -> { where('created_bike_id IS NULL') }
  scope :without_creator, -> { where('creator_id IS NULL') }

  before_create :generate_id_token

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
    params['bike']['stolen'] = val
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

  def primary_frame_color_id; bike['primary_frame_color_id'] end
  def secondary_frame_color_id; bike['secondary_frame_color_id'] end
  def tertiary_frame_color_id; bike['tertiary_frame_color_id'] end
  def manufacturer_id; bike['manufacturer_id'] end
  def stolen; bike['stolen'] end

  def manufacturer; bike['manufacturer_id'] && Manufacturer.find(bike['manufacturer_id']) end
  def creation_organization; Organization.friendly_find(creation_organization_id) end

  class << self
    def v2_params(hash)
      h = { 'bike' => hash.with_indifferent_access }
      h['bike']['serial_number'] = h['bike'].delete 'serial'
      h['bike']['send_email'] = !(h['bike'].delete 'no_notify')
      org = Organization.find_by_slug(h['bike'].delete 'organization_slug')
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

    def from_id_token(toke, after = nil)
      return nil unless toke.present?
      after ||= Time.now - 1.days
      where('created_at >= ?', after).where(id_token: toke).first
    end

    def find_or_new_from_token(toke = nil, user_id: nil, organization_id: nil)
      b = where(creator_id: user_id, id_token: toke).first if user_id.present?
      b ||= without_bike.without_creator.where('created_at >= ?', Time.now - 1.month).where(id_token: toke).first
      b ||= BParam.new(creator_id: user_id, params: { revised_new: true }.as_json)
      b.creator_id ||= user_id
      # If the org_id is present, add it to the params. Only save it if the b_param is created
      if organization_id.present? && b.creation_organization_id != organization_id
        b.params = b.params.merge(bike: b.bike.merge(creation_organization_id: organization_id))
        b.update_attribute :params, b.params if b.id.present?
      end
      b
    end

    def assignable_attrs
      %w(manufacturer_id manufacturer_other frame_model year owner_email
         stolen recovered serial_number has_no_serial made_without_serial
         primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id)
    end

    def skipped_bike_attrs # Attrs that need to be skipped on bike assignment
      %w(cycle_type_slug cycle_type_name rear_gear_type_slug front_gear_type_slug
         handlebar_type_slug frame_material_slug)
    end
  end

  # Right now this is a partial update. It's improved from where it was, but it still uses the BikeCreator
  # code for protection. Ideally, we would use the revised merge code to ensure we aren't letting users
  # write illegal things to the bikes
  before_save :clean_params
  def clean_params(updated_params = {}) # So we can pass in the params
    self.params ||= { bike: {} } # ensure valid json object
    self.params = params.with_indifferent_access.deep_merge(updated_params.with_indifferent_access)
    clean_errors
    massage_if_v2
    set_foreign_keys
    self
  end

  def clean_errors
    return true unless bike_errors.present?
    self.bike_errors = bike_errors.delete_if { |a| a[/(bike can.t be blank|are you sure the bike was created)/i] }
  end

  def massage_if_v2
    self.params = self.class.v2_params(params) if api_v2
    true
  end

  def bike
    (params && params['bike'] || {}).with_indifferent_access
  end

  def set_foreign_keys
    return true unless params.present? && bike.present?
    bike['stolen'] = true if params['stolen_record'].present?
    set_wheel_size_key
    if bike['manufacturer_id'].present?
      params['bike']['manufacturer_id'] = Manufacturer.friendly_id_find(bike['manufacturer_id'])
    else
      set_manufacturer_key
    end
    set_color_key unless bike['primary_frame_color_id'].present?
    set_cycle_type_key if bike['cycle_type_slug'].present? || bike['cycle_type_name'].present?
    set_rear_gear_type_slug if bike['rear_gear_type_slug'].present?
    set_front_gear_type_slug if bike['front_gear_type_slug'].present?
    set_handlebar_type_key if bike['handlebar_type_slug'].present?
    set_frame_material_key if bike['frame_material_slug'].present?
  end

  def set_cycle_type_key
    if bike['cycle_type_name'].present?
      ct = CycleType.where('lower(name) = ?', bike['cycle_type_name'].downcase.strip).first
    else
      ct = CycleType.where('slug = ?', bike['cycle_type_slug'].downcase.strip).first
    end
    params['bike']['cycle_type_id'] = ct.id if ct.present?
    params['bike'].delete('cycle_type_slug') || params['bike'].delete('cycle_type_name')
  end

  def set_frame_material_key
    fm = FrameMaterial.where("slug = ?", bike['frame_material_slug'].downcase.strip).first
    params['bike']['frame_material_id'] = fm.id if fm.present?
    params['bike'].delete('frame_material_slug')
  end

  def set_handlebar_type_key
    ht = HandlebarType.where("slug = ?", bike['handlebar_type_slug'].downcase.strip).first
    params['bike']['handlebar_type_id'] = ht.id if ht.present?
    params['bike'].delete('handlebar_type_slug')
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

  def set_manufacturer_key
    m_name = bike['manufacturer'] if bike.present?
    return false unless m_name.present?
    manufacturer = Manufacturer.friendly_find(m_name)
    unless manufacturer.present?
      manufacturer = Manufacturer.find_by_name('Other')
      params['bike']['manufacturer_other'] = m_name.titleize if m_name.present?
    end
    params['bike']['manufacturer_id'] = manufacturer.id if manufacturer.present?
    params['bike'].delete('manufacturer')
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
      paint.manufacturer_id = bike['manufacturer_id'] if bike['registered_new']
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
    Bike.new safe_bike_attrs({ 'stolen' => is_stolen, 'recovered' => recovered }).as_json
  end

  def safe_bike_attrs(param_overrides)
    bike.merge(param_overrides).select { |k, v| self.class.assignable_attrs.include?(k.to_s) }
        .merge('b_param_id' => id,
               'creator_id' => creator_id,
               'cycle_type_id' => cycle_type_id,
               'creation_organization_id' => params['creation_organization_id'])
  end

  def cycle_type_id
    (bike['cycle_type_id'].present? && bike['cycle_type_id']) || CycleType.bike.id
  end

  def revised_new?
    params && params['revised_new']
  end

  def creation_organization_id
    bike && bike['creation_organization_id']
  end

  def owner_email
    bike && bike['owner_email']
  end

  def display_email? # For revised form. If there aren't errors and there is an email, then we don't need to show
    true unless owner_email.present? && bike_errors.blank?
  end

  protected

  def generate_unique_token
    begin
      toke = SecureRandom.urlsafe_base64
    end while BParam.where(id_token: toke).exists?
    toke
  end
end
