class MailSnippet < ApplicationRecord
  include Geocodeable

  KIND_ENUM = {
    custom: 0,
    header: 1,
    welcome: 2,
    footer: 3,
    security: 4,
    location_triggered: 5,
    partial: 6,
    appears_abandoned_notification: 7,
    parked_incorrectly_notification: 8,
    impound_notification: 9,
    graduated_notification: 10
  }.freeze

  belongs_to :state
  belongs_to :country

  belongs_to :organization
  validates_uniqueness_of :organization_id, scope: [:kind], allow_nil: true
  has_many :public_images, as: :imageable, dependent: :destroy

  scope :enabled, -> { where(is_enabled: true) }
  scope :location_triggered, -> { where(is_location_triggered: true) }
  scope :with_organizations, -> { where.not(organization_id: nil) }
  scope :without_organizations, -> { where(organization_id: nil) }

  enum kind: KIND_ENUM

  after_commit :update_associations

  before_validation :set_calculated_attributes

  attr_accessor :skip_update

  def self.organization_snippets
    {
      header: "Top of email block",
      welcome: "Below header",
      footer: "Above <3 <3 <3 <3 Bike Index Team",
      partial: "Above \"Finish it\" button, in email \"Partial registration\"",
      security: "How to keep your bike safe, in email \"Finished registration\""
    }.as_json
  end

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.organization_snippet_kinds
    organization_snippets.keys
  end

  def self.organization_message_kinds
    ParkingNotification.kinds + ["graduated_notification"]
  end

  def self.finished_registration_kinds
    %w[welcome footer security]
  end

  def organization_snippet?
    self.class.organization_snippet_kinds.include?(kind)
  end

  def organization_message?
    self.class.organization_message_kinds.include?(kind)
  end

  def set_calculated_attributes
    self.is_enabled = false if is_enabled && body.blank?
    if is_location_triggered # No longer used, but keeping in case we decide to use. Check PR#415
      self.kind = "location_triggered"
    elsif kind.blank?
      self.kind = "custom"
    end
  end

  def update_associations
    return true if skip_update
    # Because we need to update the organization and make sure mail snippet calculations are included
    # Manually update to ensure that it runs the before save stuff
    organization&.update(updated_at: Time.current)
  end

  private

  def should_be_geocoded?
    return false if skip_geocoding?
    return true if is_location_triggered?
    return false if address.blank?
    address_changed?
  end
end
