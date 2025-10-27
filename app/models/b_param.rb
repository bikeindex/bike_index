# == Schema Information
#
# Table name: b_params
#
#  id              :integer          not null, primary key
#  bike_errors     :text
#  bike_title      :string(255)
#  email           :string
#  id_token        :text
#  image           :string(255)
#  image_processed :boolean          default(FALSE)
#  image_tmp       :string(255)
#  origin          :string
#  params          :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_bike_id :integer
#  creator_id      :integer
#  organization_id :integer
#
# Indexes
#
#  index_b_params_on_organization_id  (organization_id)
#

# b_param stands for Bike param
class BParam < ApplicationRecord
  # Also uses address_record_attributes to get legacy address attributes
  REGISTRATION_INFO_ATTRS = %w[
    accuracy
    bike_code
    bike_sticker
    city
    country_id
    organization_affiliation
    phone
    postal_code
    region_string
    street
    student_id
    user_name
  ].freeze
  # attrs that need to be skipped on bike assignment, mostly legacy reasons
  SKIPPED_BIKE_ATTRS = %w[
    abandoned
    accuracy
    address
    address_city
    address_country
    address_state
    address_zipcode
    bike_code
    bike_sticker
    city
    country
    country_id
    cycle_type_name
    cycle_type_slug
    front_gear_type_slug
    handlebar_type_slug
    is_bulk
    is_new
    is_pos
    no_duplicate
    propulsion_type
    propulsion_type_slug
    rear_gear_type_slug
    revised_new
    state
    state_id
    stolen
    street
    zipcode
  ].freeze
  mount_uploader :image, ImageUploader
  process_in_background :image, CarrierWaveStoreJob

  attr_writer :image_cache

  serialize :bike_errors, coder: YAML

  belongs_to :created_bike, class_name: "Bike"
  belongs_to :creator, class_name: "User"
  belongs_to :organization

  scope :with_bike, -> { where.not(created_bike_id: nil) }
  scope :without_bike, -> { where(created_bike_id: nil) }
  scope :without_creator, -> { where(creator_id: nil) }
  scope :partial_registrations, -> { where(origin: "embed_partial") }
  scope :bike_params, -> { where("(params -> 'bike') IS NOT NULL") }
  scope :bike_params_empty, -> { where("(params -> 'bike') IS NULL") } # failsafe, shouldn't happen!
  scope :unprocessed_image, -> { where(image_processed: false).where.not(image: nil) }
  scope :with_cycle_type, -> { bike_params.where("(params -> 'bike' -> 'cycle_type') IS NOT NULL") }
  scope :cycle_type_bike, -> { bike_params.where("(params -> 'bike' -> 'cycle_type') IS NULL").or(bike_params_empty) }
  scope :cycle_type_not_bike, -> { with_cycle_type } # currently just an alias
  scope :cycle_type_not_bike_ordered, -> { with_cycle_type.order(Arel.sql("(params -> 'bike' ->> 'cycle_type') DESC")) }
  scope :top_level_motorized, -> { bike_params.where("(params -> 'propulsion_type_motorized') IS NOT NULL") }

  after_initialize :ensure_valid_params
  before_create :generate_id_token
  before_save :clean_params

  class << self
    def motorized
      # TODO: check if this scope just works in Rails 7:
      # where("(params -> 'bike' ->> 'cycle_type') = ?", CycleType::ALWAYS_MOTORIZED)
      matching = top_level_motorized
      CycleType::ALWAYS_MOTORIZED.each do |cycle_type|
        matching = matching.or(where("(params -> 'bike' ->> 'cycle_type') = ?", cycle_type.to_s))
      end
      matching
    end

    def v2_params(hash)
      h = hash["bike"].present? ? hash : {"bike" => hash.with_indifferent_access}
      h["bike"].delete("bike") if h["bike"]["bike"].blank? # it's assigned before save :/
      # Only assign if the key hasn't been assigned - since it's boolean, can't use conditional assignment
      h["bike"]["serial_number"] = h["bike"].delete "serial" if h["bike"].key?("serial")
      h["bike"]["send_email"] = !(h["bike"].delete "no_notify") unless h["bike"].key?("send_email")
      if h["bike"].key?("owner_email_is_phone_number")
        h["bike"]["is_phone"] = InputNormalizer.boolean(h["bike"].delete("owner_email_is_phone_number"))
      end
      org = Organization.friendly_find(h["bike"].delete("organization_slug"))
      h["bike"]["creation_organization_id"] = org.id if org.present?
      # Move un-nested params outside of bike
      %w[test id components].each { |k| h[k] = h["bike"].delete(k) if h["bike"].key?(k) }
      stolen_attrs = h["bike"].delete "stolen_record"
      if stolen_attrs.present? && stolen_attrs.delete_if { |k, v| v.blank? } && stolen_attrs.keys.any?
        h["stolen_record"] = stolen_attrs
        h["stolen_record"]["street"] = h["stolen_record"].delete("address") if h["stolen_record"]["address"].present?
      end
      h
    end

    def find_or_new_from_token(toke = nil, user_id: nil, organization_id: nil, bike_sticker: nil)
      b = where(creator_id: user_id, id_token: toke).first if toke.present? && user_id.present?
      b ||= with_organization_or_no_creator(toke)
      b ||= BParam.new(creator_id: user_id, params: {revised_new: true}.as_json)
      b.creator_id ||= user_id
      if bike_sticker.present?
        b.origin = "sticker"
        b.params["bike"] = b.bike.merge("bike_sticker" => bike_sticker.pretty_code)
        organization_id = bike_sticker.organization_id if bike_sticker.organization_id.present?
      end
      # If the org_id is present, add it to the params. Only save it if the b_param is created_at
      if organization_id.present? && b.creation_organization_id != organization_id
        b.params = b.params.merge("bike" => b.bike.merge("creation_organization_id" => organization_id))
        b.update_attribute :params, b.params if b.id.present?
      end
      # Assign the correct user if user is part of the org (for embed submissions)
      if b.creation_organization_id.present? && b.creator_id != user_id
        if OrganizationRole.where(user_id: user_id, organization_id: b.creation_organization_id).present?
          b.update_attribute :creator_id, user_id
        end
      end
      b
    end

    # Because organization embed bikes might not match the creator
    def with_organization_or_no_creator(toke)
      without_bike.where("created_at >= ?", Time.current - 1.month).where(id_token: toke)
        .detect { |b| b.creator_id.blank? || b.creation_organization_id.present? || b.params["creation_organization_id"].present? }
    end

    def email_search(str)
      return all unless str.present?

      where("email ilike ?", "%#{str.strip}%")
    end

    # There are URLs out there with stolen=true, and will be forever - so lean in
    # Keywords are - :status, :stolen
    def status_hash_from_params(action_controller_params = nil)
      url_params = action_controller_params&.permit(:status, :stolen).to_h
      status = url_params[:status]
      if status.present?
        status = "status_#{status}" unless status.start_with?("status_")
        status = "status_impounded" if status == "status_found" # Rename, so we can give pretty URLs to users
        return {status: status} if Bike.statuses.include?(status)
      end
      return {status: "status_stolen"} if InputNormalizer.boolean(url_params[:stolen])

      {}
    end

    # NOTE: Does not restrict to valid propulsion_types, it's allow-listed in safe_bike_attrs
    def propulsion_type(passed_params)
      return nil if passed_params.blank?

      throttle = InputNormalizer.boolean(passed_params["propulsion_type_throttle"])
      pedal_assist = InputNormalizer.boolean(passed_params["propulsion_type_pedal_assist"])

      if pedal_assist
        throttle ? "pedal-assist-and-throttle" : "pedal-assist"
      elsif throttle
        "throttle"
      elsif InputNormalizer.boolean(passed_params["propulsion_type_motorized"])
        "motorized"
      else
        passed_params["propulsion_type_slug"] || passed_params["propulsion_type"] ||
          propulsion_type(passed_params["bike"])
      end
    end

    def matching_domain(str)
      where("(params -> 'bike' ->> 'owner_email') ILIKE ?", "%#{str.to_s.strip}")
    end

    # NOTE:
    def address_record_attributes(bike_params)
      # If nested address_record_attributes hash is present, no legacy handling required!
      ar_attrs = bike_params["address_record_attributes"]&.slice(*AddressRecord.permitted_params.map(&:to_s))
      ar_attrs ||= AddressRecord.permitted_params.map { |k| [k, legacy_address_field_value(bike_params, k)] }.to_h

      ar_attrs.values.any? ? ar_attrs.compact.merge(kind: "ownership") : {}
    end

    private

    # Deal with the legacy address concerns
    def legacy_address_field_value(bike_params, field)
      if field == :street # If looking for street or address, try both street and address
        bike_params["street"] || bike_params["address"] || bike_params["address_street"]
      elsif field == :postal_code
        bike_params[field.to_s] || bike_params["zipcode"] || bike_params["address_zipcode"]
      elsif field == :region_string
        bike_params[field.to_s] || bike_params["state"] || bike_params["address_state"]
      elsif field == :country_id
        bike_params[field.to_s] || bike_params["country"] || bike_params["address_country"]
      else
        bike_params[field.to_s] || bike_params["address_#{field}"]
      end
    end
  end

  # Crazy new shit
  def manufacturer_id=(val)
    assign_bike_val("manufacturer_id", val)
  end

  def creation_organization_id=(val)
    assign_bike_val("creation_organization_id", val)
  end

  def owner_email=(val)
    assign_bike_val("owner_email", val)
  end

  def primary_frame_color_id=(val)
    assign_bike_val("primary_frame_color_id", val)
  end

  def secondary_frame_color_id=(val)
    assign_bike_val("secondary_frame_color_id", val)
  end

  def tertiary_frame_color_id=(val)
    assign_bike_val("tertiary_frame_color_id", val)
  end

  def status=(val)
    assign_bike_val("status", val)
  end

  # Used by partial registration
  def cycle_type=(val)
    assign_bike_val("cycle_type", val)
  end

  # Used by partial registration
  def cycle_type
    bike["cycle_type"] || CycleType.default_slug
  end

  # Used by partial registration
  def propulsion_type_motorized=(val)
    params["propulsion_type_motorized"] = val
  end

  # Used by partial registration
  def motorized?
    PropulsionType.motorized?(self.class.propulsion_type(params)) ||
      PropulsionType.motorized?(PropulsionType.for_vehicle(cycle_type)) # Fallback to PropulsionType lookup
  end

  def with_bike?
    created_bike_id.present?
  end

  # Get it unscoped, because unregistered_bike notifications
  def created_bike
    @created_bike ||= created_bike_id.present? ? Bike.unscoped.find_by_id(created_bike_id) : nil
  end

  def bike
    (params && params["bike"] || {}).with_indifferent_access
  end

  def stolen_attrs
    s_attrs = params["stolen_record"] || {}
    nested_params = params.dig("bike", "stolen_records_attributes")
    if nested_params&.values&.first.is_a?(Hash)
      s_attrs = nested_params.values.reject(&:blank?).last
    end
    # Set the date_stolen if it was passed, if something else didn't already set date_stolen
    date_stolen = params.dig("bike", "date_stolen")
    s_attrs["date_stolen"] ||= date_stolen if date_stolen.present?
    s_attrs.except("phone_no_show", "show_address")
  end

  def impound_attrs
    s_attrs = params["impound_record"] || {}
    nested_params = params.dig("bike", "impound_records_attributes")
    if nested_params&.values&.first.is_a?(Hash)
      s_attrs = nested_params.values.reject(&:blank?).last
    end
    s_attrs
  end

  # registration_info_attrs is assigned to ownership. Update to use address_record_attributes in #2922
  def registration_info_attrs
    ria = params["bike"]&.slice(*REGISTRATION_INFO_ATTRS) || {}
    # Include legacy address attributes
    (ria.key?("street") ? ria : ria.merge(self.class.address_record_attributes(bike))).reject { |_k, v| v.blank? }.to_h
  end

  def status
    if Bike.statuses.include?(bike["status"])
      # Don't override status with status_with_owner
      return bike["status"] unless bike["status"] == "status_with_owner"
    end
    return "unregistered_parking_notification" if parking_notification_params.present?
    return "status_impounded" if impound_attrs.present?
    return "status_stolen" if stolen_attrs.present? || InputNormalizer.boolean(bike["stolen"])

    "status_with_owner"
  end

  def status_stolen?
    status == "status_stolen"
  end

  def status_abandoned?
    status == "status_abandoned"
  end

  def status_impounded?
    status == "status_impounded"
  end

  def unregistered_parking_notification?
    status == "unregistered_parking_notification"
  end

  def primary_frame_color_id
    bike["primary_frame_color_id"]
  end

  def secondary_frame_color_id
    bike["secondary_frame_color_id"]
  end

  def tertiary_frame_color_id
    bike["tertiary_frame_color_id"]
  end

  def manufacturer_id
    bike["manufacturer_id"]
  end

  def is_pos
    bike["is_pos"] || false
  end

  def is_new
    bike["is_new"] || false
  end

  def bulk_import
    BulkImport.find_by_id(params["bulk_import_id"])
  end

  def pos_kind
    return "lightspeed_pos" if is_pos

    bulk_import&.ascend? ? "ascend_pos" : "no_pos"
  end

  def is_bulk
    bike["is_bulk"] || false
  end

  def no_duplicate?
    bike["no_duplicate"] || false
  end

  def bike_sticker_code
    bike["bike_sticker"].presence || bike["bike_code"].presence
  end

  def phone
    Phonifyer.phonify(params.dig("stolen_record", "phone") || bike["phone"])
  end

  def user_name
    bike["user_name"]
  end

  def creation_organization
    Organization.friendly_find(creation_organization_id)
  end

  def manufacturer
    bike["manufacturer_id"] && Manufacturer.friendly_find(bike["manufacturer_id"])
  end

  def partial_registration?
    origin == "embed_partial"
  end

  def primary_frame_color
    primary_frame_color_id.present? && Color.find_by_id(primary_frame_color_id)&.name
  end

  def revised_new?
    params && params["revised_new"]
  end

  def creation_organization_id
    bike && bike["creation_organization_id"] || params && params["creation_organization_id"]
  end

  def owner_email
    bike && bike["owner_email"]
  end

  def skip_email?
    return true if status_impounded? || unregistered_parking_notification?

    send_email = params.dig("bike", "send_email").to_s
    send_email.present? && !InputNormalizer.boolean(send_email)
  end

  def organization_affiliation
    bike["organization_affiliation"]
  end

  def student_id
    bike["student_id"]
  end

  def external_image_urls
    bike["external_image_urls"] || []
  end

  # For revised form. If there aren't errors and there is an email, then we don't need to show
  def display_email?
    true unless owner_email.present? && bike_errors.blank?
  end

  # Right now this is a partial update. It's improved from where it was, but it still uses the BikeServices::Creator
  # code for protection. Ideally, we would use the revised merge code to ensure we aren't letting users
  # write illegal things to the bikes
  # args are not named so we can pass in the params
  def clean_params(updated_params = {})
    ensure_valid_params
    process_image_if_required
    self.params = params.with_indifferent_access.deep_merge(updated_params.with_indifferent_access)
    massage_if_v2
    set_foreign_keys
    # Remove false top level param (this is gross and I wish it wasn't necessary)
    params.delete("propulsion_type_motorized") unless InputNormalizer.boolean(params["propulsion_type_motorized"])
    self.organization_id = creation_organization_id
    self.email = owner_email
    self
  end

  def massage_if_v2
    self.params = self.class.v2_params(params) if %w[api_v2 api_v3].include?(origin)
    true
  end

  def set_foreign_keys
    return true unless bike.present?

    set_wheel_size_key
    set_manufacturer_key
    set_color_keys
    set_cycle_type_key
    set_rear_gear_type_slug if bike["rear_gear_type_slug"].present?
    set_front_gear_type_slug if bike["front_gear_type_slug"].present?
    set_handlebar_type_key
    set_frame_material_key # Even if the value isn't present, since we need to remove the key
  end

  def set_handlebar_type_key
    key = bike["handlebar_type"] || bike["handlebar_type_slug"]
    params["bike"].delete("handlebar_type")
    params["bike"].delete("handlebar_type_slug")
    ht = HandlebarType.friendly_find(key)
    params["bike"]["handlebar_type"] = ht&.slug if ht.present?
  end

  def set_cycle_type_key
    key = (bike["cycle_type"] || bike["cycle_type_slug"] || bike["cycle_type_name"]).presence
    cycle_type_slug = CycleType.friendly_find(key)&.slug
    params["bike"].delete("cycle_type")
    params["bike"].delete("cycle_type_slug")
    params["bike"].delete("cycle_type_name")
    return if cycle_type_slug.blank? || cycle_type_slug&.to_s == CycleType.default_slug

    params["bike"]["cycle_type"] = cycle_type_slug
  end

  def set_wheel_size_key
    if bike.key?("rear_wheel_bsd")
      key = "_wheel_bsd"
    elsif bike["rear_wheel_size"].present?
      key = "_wheel_size"
    else
      return nil
    end
    rbsd = params["bike"].delete("rear#{key}")
    fbsd = params["bike"].delete("front#{key}")
    params["bike"]["rear_wheel_size_id"] = WheelSize.id_for_bsd(rbsd)
    params["bike"]["front_wheel_size_id"] = WheelSize.id_for_bsd(fbsd)
  end

  def set_frame_material_key
    frame_material = FrameMaterial.friendly_find(bike["frame_material_slug"])
    params["bike"]["frame_material"] = frame_material.slug if frame_material.present?
    params["bike"].delete("frame_material_slug")
  end

  def set_manufacturer_key
    return false unless bike.present?

    m = params["bike"].delete("manufacturer")
    m = params["bike"].delete("manufacturer_id") unless m.present?
    return nil unless m.present?

    b_manufacturer = Manufacturer.friendly_find(m)
    unless b_manufacturer.present?
      b_manufacturer = Manufacturer.other
      params["bike"]["manufacturer_other"] = m
    end
    params["bike"]["manufacturer_id"] = b_manufacturer.id
  end

  def set_rear_gear_type_slug
    gear = RearGearType.where(slug: params["bike"].delete("rear_gear_type_slug")).first
    params["bike"]["rear_gear_type_id"] = gear && gear.id
  end

  def set_front_gear_type_slug
    gear = FrontGearType.where(slug: params["bike"].delete("front_gear_type_slug")).first
    params["bike"]["front_gear_type_id"] = gear && gear.id
  end

  def set_color_keys
    %w[
      primary_frame_color
      secondary_frame_color
      tertiary_frame_color
    ].each { |key| set_color_key(key) }
  end

  def set_paint_key(paint_entry)
    return nil unless paint_entry.present?

    paint = Paint.friendly_find(paint_entry)

    if paint.present?
      params["bike"]["paint_id"] = paint.id
    else
      paint = Paint.new(name: paint_entry)
      paint.manufacturer_id = bike["manufacturer_id"] if is_pos
      paint.save
      params["bike"]["paint_id"] = paint.id
      params["bike"]["paint_name"] = paint.name
    end

    unless bike["primary_frame_color_id"].present?
      params["bike"]["primary_frame_color_id"] = if paint.color_id.present?
        paint.color.id
      else
        Color.black.id
      end
    end
  end

  def mnfg_name
    Manufacturer.calculated_mnfg_name(manufacturer, bike["manufacturer_other"])
  end

  def generate_id_token
    self.id_token ||= SecurityTokenizer.new_token
  end

  def parking_notification_params
    return nil unless params&.dig("parking_notification").present?

    attrs = params["parking_notification"].with_indifferent_access
      .slice(:latitude, :longitude, :kind, :internal_notes, :message, :accuracy,
        :use_entered_address, :street, :city, :zipcode, :state_id, :country_id)
    attrs.merge(organization_id: creation_organization_id,
      user_id: creator_id,
      bike_id: created_bike_id,
      use_entered_address: InputNormalizer.boolean(attrs[:use_entered_address]))
  end

  def partial_notification_pre_tracking?
    (created_at || Time.current) < Email::PartialRegistrationJob::NOTIFICATION_STARTED
  end

  def partial_notification_resends
    return partial_notifications if partial_notification_pre_tracking?

    partial_notifications.offset(1)
  end

  def partial_notifications
    Notification.partial_registration.where(notifiable: self).order(:id)
  end

  # Below here is revised setup

  def safe_bike_attrs(new_attrs)
    # existing bike attrs, overridden with passed attributes
    attrs_merged = bike.merge("status" => status).merge(new_attrs.as_json)
    addy_hash = self.class.address_record_attributes(attrs_merged)

    attrs_merged.except(*SKIPPED_BIKE_ATTRS)
      .map { |k, v| clean_key_value(k, v) }.compact.to_h
      .merge("b_param_id" => id,
        "b_param_id_token" => id_token,
        "creator_id" => creator_id,
        "updator_id" => creator_id,
        # propulsion_type_slug safe assigns, verifying against cycle_type (in BikeAttributable)
        "propulsion_type_slug" => self.class.propulsion_type(params.merge("bike" => attrs_merged)))
      .merge(addy_hash.blank? ? {} : {"address_record_attributes" => addy_hash})
  end

  private

  def ensure_valid_params
    self.params ||= {"bike" => {}}
    self.params["bike"] ||= {}
  end

  def assign_bike_val(key, val)
    ensure_valid_params
    self.params["bike"][key] = val
  end

  def clean_key_value(key, value)
    return unless InputNormalizer.present_or_false?(value)

    clean_value = value.is_a?(String) ? InputNormalizer.sanitize(value) : value
    [key, clean_value]
  end

  def process_image_if_required
    return true if image_processed || image.blank?

    Images::AssociatorJob.perform_in(5.seconds)
    Images::AssociatorJob.perform_in(1.minutes)
  end

  def set_color_key(key = nil)
    # If the ID is present, remove the non-id param
    if params.dig("bike", "#{key}_id").present?
      params["bike"].delete(key)
      return
    end

    # Set the paint from color param, if in primary_frame_color
    if key == "primary_frame_color"
      paint = params.dig("bike", "color") || params.dig("bike", key)
      color = Color.friendly_find(paint.strip) if paint.present?
      if color.present?
        params["bike"]["#{key}_id"] = color.id
      else
        set_paint_key(paint)
      end
      params["bike"].delete("color")
    end
    # Set the frame_color
    color = params.dig("bike", key).presence && Color.friendly_find(params.dig("bike", key))
    params["bike"]["#{key}_id"] = color.id if color.present?
    params["bike"].delete(key)
  end
end
