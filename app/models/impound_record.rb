# == Schema Information
#
# Table name: impound_records
#
#  id                    :integer          not null, primary key
#  city                  :text
#  display_id_integer    :bigint
#  display_id_prefix     :string
#  impounded_at          :datetime
#  impounded_description :text
#  latitude              :float
#  longitude             :float
#  neighborhood          :text
#  resolved_at           :datetime
#  status                :integer          default("current")
#  street                :text
#  unregistered_bike     :boolean          default(FALSE)
#  zipcode               :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  bike_id               :integer
#  country_id            :bigint
#  display_id            :string
#  location_id           :bigint
#  organization_id       :integer
#  state_id              :bigint
#  user_id               :integer
#
# Indexes
#
#  index_impound_records_on_bike_id          (bike_id)
#  index_impound_records_on_country_id       (country_id)
#  index_impound_records_on_location_id      (location_id)
#  index_impound_records_on_organization_id  (organization_id)
#  index_impound_records_on_state_id         (state_id)
#  index_impound_records_on_user_id          (user_id)
#
class ImpoundRecord < ApplicationRecord
  include Geocodeable

  belongs_to :bike, touch: true
  belongs_to :user
  belongs_to :organization
  belongs_to :location # organization location

  has_one :parking_notification
  has_one :ownership
  has_many :impound_record_updates
  has_many :impound_claims

  validates_presence_of :user_id
  validates_uniqueness_of :bike_id, if: :current?, conditions: -> { current }

  before_validation :set_calculated_attributes
  after_commit :update_associations

  enum :status, ImpoundRecordUpdate::KIND_ENUM

  scope :active, -> { where(status: active_statuses) }
  scope :resolved, -> { where(status: resolved_statuses) }
  scope :unorganized, -> { where(organization_id: nil) }
  scope :organized, -> { where.not(organization_id: nil) }
  scope :unregistered_bike, -> { where(unregistered_bike: true) }
  scope :registered_bike, -> { where(unregistered_bike: false) }
  scope :with_claims, -> { joins(:impound_claims).where.not(impound_claims: {id: nil}) }

  attr_accessor :timezone, :skip_update # timezone provides a backup and permits assignment

  def self.statuses
    ImpoundRecordUpdate::KIND_ENUM.keys.map(&:to_s) - ImpoundRecordUpdate.update_only_kinds
  end

  def self.active_statuses
    %w[current]
  end

  def self.resolved_statuses
    statuses - active_statuses
  end

  def self.statuses_humanized
    ImpoundRecordUpdate.kinds_humanized
  end

  def self.statuses_humanized_short
    ImpoundRecordUpdate.kinds_humanized_short
  end

  # Using method here to make it easier to update/translate the specific word later
  def self.impounded_kind
    "impounded"
  end

  # Using method here to make it easier to update/translate the specific word later
  def self.found_kind
    "found"
  end

  def self.friendly_find(str)
    if str.start_with?("pkey-")
      find_by_id(str.gsub("pkey-", ""))
    else
      find_by_display_id(str)
    end
  end

  def self.friendly_find!(str)
    friendly_find(str) || (raise ActiveRecord::RecordNotFound)
  end

  def self.bikes
    Bike.unscoped.where(id: pluck(:bike_id))
  end

  def impound_configuration
    organization&.fetch_impound_configuration
  end

  def impounded_at_with_timezone=(val)
    self.impounded_at = TimeParser.parse(val, timezone)
  end

  # Non-organizations don't "impound" bikes, they "find" them
  def kind
    organization_id.present? ? self.class.impounded_kind : self.class.found_kind
  end

  def authorized?(u = nil)
    return false if u.blank?
    return true if u.superuser?
    organized? ? u.authorized?(organization) : u.id == user_id
  end

  # For now at least, we don't want to show exact address
  def show_address
    false
  end

  # geocoding is managed by set_calculated_attributes
  def should_be_geocoded?
    false
  end

  # force_show_address, just like parking_notification
  def address(force_show_address: false, country: [:iso, :optional, :skip_default])
    Geocodeable.address(
      self,
      street: force_show_address || show_address,
      country: country
    ).presence
  end

  def unorganized?
    !organized?
  end

  def organized?
    organization_id.present?
  end

  def impound_claim_retrieved?
    impound_claims.retrieved.any?
  end

  def bike
    # Use retrieved impound claim, if possible - otherwise
    @bike ||= impound_claims.retrieved.first&.bike_submitting
    # Get it unscoped, because unregistered_bike notifications
    @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil
  end

  def notification_notes_and_messages
    return nil unless parking_notification.present?
    msgs = parking_notification.associated_notifications_including_self
      .map { |pn| [pn.internal_notes, pn.message] }.flatten.reject(&:blank?)
    msgs.any? ? msgs : nil
  end

  def creator
    parking_notification&.user
  end

  def creator_public_display_name
    # Not 100% convinced that "bike finder" is the right thing here, but it's better than nothing
    organization&.name || "#{bike.type} finder"
  end

  def active?
    self.class.active_statuses.include?(status)
  end

  def resolved?
    !active?
  end

  def resolving_update
    impound_record_updates.resolved.order(:id).first
  end

  def status_humanized
    self.class.statuses_humanized[status.to_sym]
  end

  def status_humanized_short
    self.class.statuses_humanized_short[status.to_sym]
  end

  def update_kinds
    return ["note"] if resolved?
    u_kinds = ImpoundRecordUpdate.kinds - ["expired"]
    u_kinds -= %w[move_location] unless organization&.enabled?("impound_bikes_locations")
    if impound_claims.approved.any? || impound_claims.active.none?
      u_kinds -= %w[claim_approved claim_denied]
    end
    # Unregistered bikes can't be retrieved by their owner - unless there is an impound_claim
    if unregistered_bike? && impound_claims.approved.none?
      u_kinds -= %w[retrieved_by_owner]
    end
    u_kinds
  end

  def update_multi_kinds
    u_kinds = update_kinds - %w[current expired]
    return u_kinds if resolved? || impound_claims.submitted.active.none?
    # If there are approved claims, you can have the bike retrieved_by_owner, but can't approve other claims
    u_kinds - if impound_claims.approved.any?
      %w[removed_from_bike_index transferred_to_new_owner claim_approved]
    else
      # If there are any active claims, you can't transfer or remove the bike
      %w[removed_from_bike_index transferred_to_new_owner retrieved_by_owner]
    end
  end

  def update_associations
    # We call this job inline in ProcessParkingNotificationJob
    return true if skip_update || !persisted?
    ProcessImpoundUpdatesJob.perform_async(id)
  end

  def set_calculated_attributes
    set_calculated_display_id if id.blank? || display_id_integer.blank? || organization_id.blank?
    self.status = calculated_status
    self.resolved_at = resolving_update&.created_at
    self.location_id = calculated_location_id
    self.user_id = calculated_user_id
    self.impounded_at ||= created_at || Time.current
    # unregistered_bike means essentially that the bike was created for this impound record
    self.unregistered_bike ||= calculated_unregistered_bike?
    # Don't geocode if location is present and address hasn't changed
    return if !address_changed? && with_location?
    self.attributes = if parking_notification.present?
      parking_notification.attributes.slice(*Geocodeable.location_attrs)
    else
      GeocodeHelper.assignable_address_hash_for(address(force_show_address: true))
    end
  end

  def reply_to_email
    # Delegate to parking notification, since that's the original email
    return parking_notification.reply_to_email if parking_notification.present?
    organization&.fetch_impound_configuration&.email ||
      organization&.auto_user&.email ||
      user&.email
  end

  private

  def set_calculated_display_id
    if organization_id.blank?
      # Force nil display_id for non-organized records
      return self.attributes = {display_id: nil, display_id_prefix: nil, display_id_integer: nil}
    end
    if @display_id_from_calculation
      # Blank the integer if calculated, so it can be reassigned
      self.display_id_integer = nil
    elsif display_id.present?
      return # If display_id was set, and it wasn't set by calculation - let it ride
    else
      # So that if we resave, we don't use the stored display_id
      @display_id_from_calculation = display_id_integer.blank?
    end
    self.display_id_prefix ||= impound_configuration.display_id_prefix
    self.display_id_integer ||= impound_configuration.calculated_display_id_next_integer
    self.display_id = "#{display_id_prefix}#{display_id_integer}"
  end

  def calculated_status
    return resolving_update.kind if resolving_update.present?
    "current"
  end

  def calculated_location_id
    # Return the existing location_id if the organization doesn't have locations enabled - just to be safe and not lose data
    return location_id unless organization&.enabled?("impound_bikes_locations")
    # If any impound records have a set location, use that, otherwise, use the existing. Fall back to the default location
    impound_record_updates.with_location.order(:id).last&.location_id || location_id.presence || organization.default_impound_location&.id
  end

  def calculated_user_id
    if impound_record_updates.where.not(user_id: nil).any?
      impound_record_updates.where.not(user_id: nil).reorder(:id).last&.user_id
    else
      user_id.present? ? user_id : organization.auto_user&.id
    end
  end

  def calculated_unregistered_bike?
    return true if parking_notification&.unregistered_bike?
    b_created_at = bike&.created_at || Time.current

    if id.blank?
      return true if bike.present? && bike.created_at.blank?
      return true if b_created_at > Time.current - 1.hour
    end
    bike&.current_ownership&.status == "status_impounded" &&
      (created_at || Time.current).between?(b_created_at - 1.hour, b_created_at + 1.hour)
  end
end
