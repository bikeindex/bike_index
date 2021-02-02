class ImpoundRecord < ApplicationRecord
  include Geocodeable

  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :location # organization location

  has_one :parking_notification
  has_many :impound_record_updates
  has_many :impound_claims

  validates_presence_of :user_id
  validates_uniqueness_of :bike_id, if: :current?, conditions: -> { current }

  before_validation :set_calculated_attributes
  after_commit :update_associations

  enum status: ImpoundRecordUpdate::KIND_ENUM

  scope :active, -> { where(status: active_statuses) }
  scope :resolved, -> { where(status: resolved_statuses) }

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

  def self.bikes
    Bike.unscoped.includes(:impound_records)
      .where(impound_records: {id: pluck(:id)})
  end

  def impounded_at_with_timezone(passed_impounded_at, passed_timezone)
    return unless passed_impounded_at.present?
    self.impounded_at = TimeParser.parse(passed_impounded_at, passed_timezone)
  end

  # Non-organizations don't "impound" bikes, they "find" them
  def kind
    organization_id.present? ? self.class.impounded_kind : self.class.found_kind
  end

  # For now at least, we don't want to show exact address
  def show_address
    false
  end

  def latitude_public
    latitude.round(2)
  end

  def longitude_public
    longitude.round(2)
  end

  # geocoding is managed by set_calculated_attributes
  def should_be_geocoded?
    false
  end

  # force_show_address, just like stolen_record & parking_notification
  def address(skip_default_country: false, force_show_address: false)
    Geocodeable.address(
      self,
      street: (force_show_address || show_address),
      country: %i[skip_default optional]
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

  # When there are non-organized impounds, extra logic will be necessary here
  def creator_public_display_name
    organization.name
  end

  def active?
    self.class.active_statuses.include?(status)
  end

  def resolved?
    !active?
  end

  def unregistered_bike?
    parking_notification&.unregistered_bike? || false
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
    u_kinds = ImpoundRecordUpdate.kinds
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

  def update_associations
    # We call this job inline in ProcessParkingNotificationWorker
    return true if skip_update || !persisted?
    ImpoundUpdateBikeWorker.perform_async(id)
  end

  def set_calculated_attributes
    self.display_id ||= calculated_display_id
    self.status = calculated_status
    self.resolved_at = resolving_update&.created_at
    self.location_id = calculated_location_id
    self.user_id = calculated_user_id
    self.impounded_at ||= created_at || Time.current
    # Don't geocode if location is present and address hasn't changed
    return if !address_changed? && with_location?
    self.attributes = if parking_notification.present?
      parking_notification.attributes.slice(*Geocodeable.location_attrs)
    else
      Geohelper.assignable_address_hash(address(force_show_address: true))
    end
  end

  def last_display_id
    irs = ImpoundRecord.where(organization_id: organization_id).where.not(display_id: nil)
    irs = irs.where("id < ?", id) if id.present?
    irs.maximum(:display_id) || 0
  end

  private

  def calculated_display_id
    return nil if organization_id.blank?
    default_display_id = last_display_id + 1
    return default_display_id unless ImpoundRecord.where(organization_id: organization_id, display_id: default_display_id)
    ImpoundRecord.where(organization_id: organization_id).maximum(:display_id).to_i + 1
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
    return user_id if impound_record_updates.where.not(user_id: nil).none?
    impound_record_updates.where.not(user_id: nil).reorder(:id).last&.user_id
  end
end
