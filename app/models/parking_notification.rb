# frozen_string_literal: true

# == Schema Information
#
# Table name: parking_notifications
# Database name: primary
#
#  id                    :integer          not null, primary key
#  accuracy              :float
#  city                  :string
#  delivery_status       :string
#  hide_address          :boolean          default(FALSE)
#  image                 :text
#  image_processing      :boolean          default(FALSE), not null
#  internal_notes        :text
#  kind                  :integer          default("appears_abandoned_notification")
#  latitude              :float
#  location_from_address :boolean          default(FALSE)
#  longitude             :float
#  message               :text
#  neighborhood          :string
#  repeat_number         :integer
#  resolved_at           :datetime
#  retrieval_link_token  :text
#  retrieved_kind        :integer
#  status                :integer          default("current")
#  street                :string
#  unregistered_bike     :boolean          default(FALSE)
#  zipcode               :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  bike_id               :integer
#  country_id            :bigint
#  impound_record_id     :integer
#  initial_record_id     :integer
#  organization_id       :integer
#  retrieved_by_id       :bigint
#  state_id              :bigint
#  user_id               :integer
#
# Indexes
#
#  index_parking_notifications_on_bike_id            (bike_id)
#  index_parking_notifications_on_country_id         (country_id)
#  index_parking_notifications_on_impound_record_id  (impound_record_id)
#  index_parking_notifications_on_initial_record_id  (initial_record_id)
#  index_parking_notifications_on_organization_id    (organization_id)
#  index_parking_notifications_on_retrieved_by_id    (retrieved_by_id)
#  index_parking_notifications_on_state_id           (state_id)
#  index_parking_notifications_on_user_id            (user_id)
#
class ParkingNotification < ActiveRecord::Base
  include Geocodeable

  KIND_ENUM = {appears_abandoned_notification: 0, parked_incorrectly_notification: 1, impound_notification: 2, other_parking_notification: 3}.freeze
  STATUS_ENUM = {current: 0, replaced: 1, impounded: 2, retrieved: 3, impounded_retrieved: 5, resolved_otherwise: 4}.freeze
  RETRIEVED_KIND_ENUM = {organization_recovery: 0, link_token_recovery: 1, user_recovery: 2, ownership_transfer: 3}.freeze
  MAX_PER_PAGE = 250

  mount_uploader :image, ImageUploaderBackgrounded
  process_in_background :image

  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :impound_record
  belongs_to :initial_record, class_name: "ParkingNotification"
  belongs_to :retrieved_by, class_name: "User"

  has_many :repeat_records, class_name: "ParkingNotification", foreign_key: :initial_record_id

  validates_presence_of :bike_id, :user_id
  validate :location_present, on: :create

  before_validation :set_calculated_attributes
  after_commit :process_notification

  enum :kind, KIND_ENUM
  enum :status, STATUS_ENUM
  enum :retrieved_kind, RETRIEVED_KIND_ENUM

  attr_accessor :is_repeat, :use_entered_address, :image_cache, :skip_update

  scope :active, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :initial_records, -> { where(initial_record_id: nil) }
  scope :repeat_records, -> { where.not(initial_record_id: nil) }
  scope :with_impound_record, -> { where.not(impound_record_id: nil) }
  scope :email_success, -> { where(delivery_status: "email_success") }
  scope :send_email, -> { where.not(unregistered_bike: true) }
  scope :unregistered_bike, -> { where(unregistered_bike: true) }
  scope :not_unregistered_bike, -> { where(unregistered_bike: false) }
  scope :first_notification, -> { where(repeat_number: 0) }
  scope :not_replaced, -> { where.not(status: "replaced") }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  def self.kinds_humanized
    {
      appears_abandoned_notification: "Appears abandoned",
      parked_incorrectly_notification: "Parked incorrectly",
      impound_notification: "Impounded",
      other_parking_notification: "Other"
    }
  end

  def self.associated_notifications_including_self(id, initial_record_id)
    potential_id_matches = [id, initial_record_id].compact
    where(initial_record_id: potential_id_matches).or(where(id: potential_id_matches))
  end

  def self.associated_notifications(id, initial_record_id)
    potential_id_matches = [id, initial_record_id].compact
    where(initial_record_id: potential_id_matches).where.not(id: id)
      .or(where(id: initial_record_id))
  end

  def self.bikes
    Bike.unscoped.includes(:parking_notifications)
      .where(parking_notifications: {id: pluck(:id)})
  end

  # Passing in an already formed bounding_box - added method to explicitly document required args
  def self.search_bounding_box(sw_lat, sw_lng, ne_lat, ne_lng)
    within_bounding_box(sw_lat, sw_lng, ne_lat, ne_lng)
  end

  # geocoding is managed by set_calculated_attributes
  def should_be_geocoded?
    false
  end

  def sent_at
    email_success? ? created_at : nil
  end

  # Get it unscoped, because unregistered_bike notifications
  def bike
    @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil
  end

  def active?
    resolved_at.blank?
  end

  def resolved?
    !active?
  end

  def email_success?
    delivery_status == "email_success"
  end

  def initial_record?
    initial_record_id.blank?
  end

  def repeat_record?
    initial_record_id.present?
  end

  def owner_known?
    !unregistered_bike? && bike&.owner_email.present?
  end

  def send_email?
    owner_known?
  end

  def show_address
    !hide_address
  end

  def kind_humanized
    self.class.kinds_humanized[kind.to_sym]
  end

  def can_be_repeat?
    potential_initial_record.present?
  end

  def email
    bike.owner_email
  end

  def reply_to_email
    if impound_notification? && organization.present?
      impound_email = organization.fetch_impound_configuration.email
      return impound_email if impound_email.present?
    end
    organization&.auto_user&.email || user&.email
  end

  def bike_notifications
    ParkingNotification.where(organization_id: organization_id, bike_id: bike_id)
  end

  def current_associated_notification
    current? ? self : associated_notifications_including_self.order(:id).last
  end

  def mail_snippet
    organization.blank? ? nil : MailSnippet.where(kind: kind, organization_id: organization_id).first
  end

  # Only initial_record and repeated records - does not include any resolved parking notifications
  def associated_notifications
    self.class.associated_notifications(id, initial_record_id)
  end

  def associated_notifications_including_self
    self.class.associated_notifications_including_self(id, initial_record_id)
  end

  def associated_retrieved_notification
    return nil unless resolved_at.present? # Used by calculated_state, so we can't use the status

    retrieved_kind.present? ? self : associated_notifications_including_self.where.not(retrieved_kind: nil).first
  end

  # Not just associated notifications - any notifications for the bike, from the organization, closed/open in the same period
  def notifications_from_period
    # Give a 1 window for resolution matching, in case things happen at slightly different times
    period_end = (resolved_at || Time.current) + 1.minute
    notifications = bike_notifications.where("created_at < ?", period_end)
    period_start = bike_notifications.resolved.where("resolved_at < ?", (resolved_at || Time.current) - 1.minute)
      .reorder(:resolved_at).last&.resolved_at
    period_start.present? ? notifications.where("created_at > ?", period_start) : notifications
  end

  def earlier_bike_notifications
    id.present? ? bike_notifications.where("id < ?", id) : bike_notifications
  end

  def potential_initial_record
    return earlier_bike_notifications.initial_records.order(:id).last unless id.blank?

    # If this is a new record, we the record needs to be current
    earlier_bike_notifications.current.initial_records.order(:id).last
  end

  def likely_repeat?
    return false unless can_be_repeat?

    # We know there has to be a potential initial record if can_be_repeat,
    # so it doesn't matter if we scope to current on new records or not
    earlier_bike_notifications.maximum(:created_at) > (created_at || Time.current) - 1.month
  end

  def notification_number
    (repeat_number || 0) + 1
  end

  # Doesn't require a user because email recovery doesn't require a user
  # args are (retrieved_kind:, retrieved_by_id: nil, resolved_at: nil) - using passed args to avoid overriding methods
  def mark_retrieved!(passed_args = {})
    return self if retrieved?
    # If replaced, mark the current notification retrieved instead, if a current notification exists
    if replaced? && calculated_later_notifications.current.last.present?
      return calculated_later_notifications.current.last.mark_retrieved!(passed_args)
    end

    self.retrieved_kind = passed_args[:retrieved_kind]
    # Assign status here because of calculated_status
    update!(status: "retrieved",
      retrieved_by_id: passed_args[:retrieved_by_id],
      resolved_at: passed_args[:resolved_at] || Time.current)
    self
  end

  # force_show_address, just like stolen_record - but this has a hide_address attr, so by default we show addresses
  def address(force_show_address: false, country: [:iso, :optional, :skip_default])
    Geocodeable.address(
      self,
      street: force_show_address || show_address,
      country: country
    ).presence
  end

  def set_location_from_organization
    self.country_id = organization&.country&.id
    self.city = organization&.city
    self.zipcode = organization&.zipcode
    self.state_id = organization&.state&.id
  end

  def set_calculated_attributes
    self.initial_record_id ||= potential_initial_record&.id if is_repeat
    self.repeat_number ||= calculated_repeat_number
    self.resolved_at ||= calculated_resolved_at # Used by by calculated_status, so must come first
    self.status = calculated_status
    # Only set unregistered_bike on creation
    self.unregistered_bike = calculated_unregistered_parking_notification if id.blank?
    # generate retrieval token after checking if unregistered_bike
    self.retrieval_link_token ||= SecurityTokenizer.new_token if current? && send_email?
    # We need to geocode on creation, unless all the attributes are present
    return true if id.present? && street.present? && latitude.present? && longitude.present?

    if !use_entered_address && latitude.present? && longitude.present?
      self.attributes = GeocodeHelper.assignable_address_hash_for(latitude: latitude, longitude: longitude)
    else
      coordinates = GeocodeHelper.coordinates_for(address)
      self.attributes = coordinates if coordinates.present?
      self.location_from_address = true
    end
  end

  def location_present
    # in case geocoder is failing (which happens sometimes), permit if either is present
    return true if latitude.present? && longitude.present? || address.present?

    errors.add(:address, :address_required)
  end

  def subject
    return mail_snippet.subject if mail_snippet&.subject.present?

    if appears_abandoned_notification?
      "Your #{bike&.type || "Bike"} appears to be abandoned"
    elsif parked_incorrectly_notification?
      "Your #{bike&.type || "Bike"} is parked incorrectly"
    elsif impounded?
      "Your #{bike&.type || "Bike"} was impounded"
    end
  end

  def process_notification
    return true if skip_update

    # Update the bike immediately, inline
    bike&.update(updated_at: Time.current)
    ProcessParkingNotificationJob.perform_async(id)
  end

  # new_attrs needs to include kind and user_id. It can include additional attrs if they matter
  def retrieve_or_repeat_notification!(new_attrs)
    new_attrs = new_attrs.with_indifferent_access
    if new_attrs.with_indifferent_access[:kind] == "mark_retrieved"
      mark_retrieved!(retrieved_by_id: new_attrs[:user_id], retrieved_kind: "organization_recovery")
    else
      return self unless active?

      attrs = attributes.except("id", "internal_notes", "created_at", "updated_at", "message",
        "location_from_address", "retrieval_link_token", "delivery_status")
        .merge(new_attrs)
      attrs["initial_record_id"] ||= id
      ParkingNotification.create!(attrs)
    end
  end

  private

  def calculated_repeat_number
    return 0 unless repeat_record?

    other_records = ParkingNotification.where(initial_record_id: initial_record_id)
    # Generally this will be called on create, so id won't be present
    other_records = other_records.where("id < ?", id) if id.present?
    other_records.count + 1
  end

  def calculated_unregistered_parking_notification
    bike&.unregistered_parking_notification? || initial_record&.unregistered_bike? || false
  end

  def calculated_later_notifications
    return ParkingNotification.none if id.blank?

    associated_notifications.where("id > ?", id)
  end

  def calculated_resolved_at
    # # If there is a resolved notification, use it for resolved_at
    resolved_notification = associated_notifications_including_self.resolved.first
    # Also set the resolved_at if this is an impound_notification
    return nil unless impound_notification? || resolved_notification.present?

    resolved_notification&.resolved_at || Time.current
  end

  def calculated_status
    return "replaced" if calculated_later_notifications.any?

    if impound_notification? || impound_record_id.present?
      impound_record&.resolved? ? "impounded_retrieved" : "impounded"
    elsif resolved_at.present?
      return "retrieved" if associated_retrieved_notification.present?

      associated_notifications.resolved.last&.status || "resolved_otherwise"
    else
      "current"
    end
  end
end
