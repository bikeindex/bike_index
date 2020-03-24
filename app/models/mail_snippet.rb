class MailSnippet < ApplicationRecord
  include Geocodeable

  KIND_ENUM = { custom: 0, header: 1, welcome: 2, footer: 3, security: 4, abandoned_bike: 5, location_triggered: 6 }.freeze
  validates_presence_of :name

  belongs_to :organization
  validates_uniqueness_of :organization_id, scope: [:name], allow_nil: true
  has_many :public_images, as: :imageable, dependent: :destroy

  scope :enabled, -> { where(is_enabled: true) }
  scope :location_triggered, -> { where(is_location_triggered: true) }
  scope :with_organizations, -> { where.not(organization_id: nil) }
  scope :without_organizations, -> { where(organization_id: nil) }

  enum kind: KIND_ENUM

  after_commit :update_organization

  before_validation :set_calculated_attributes

  def self.organization_snippets
    {
      header: "Top of email block",
      welcome: "Below header",
      footer: "Above <3 <3 <3 <3 Bike Index Team",
      partial: "Below \"Finish it\" button, in email \"Partial registration\"",
      security: "How to keep your bike safe, in email \"Finished registration\"",
      abandoned_bike: "Geocoded abandoned bike email",
    }.as_json
  end

  def self.organization_snippet_types
    organization_snippets.keys
  end

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def set_calculated_attributes
    self.is_enabled = false if is_enabled && body.blank?
    if is_location_triggered # No longer used, but keeping in case we decide to use. Check PR#415
      self.kind = "location_triggered"
    else
      self.kind = self.class.kinds.include?(name) ? name : "custom"
    end
  end

  def update_organization
    # Because we need to update the organization and make sure mail snippet calculations are included
    # Manually update to ensure that it runs the before save stuff
    organization && organization.update(updated_at: Time.current)
  end

  private

  def should_be_geocoded?
    return false if skip_geocoding?
    return true if is_location_triggered?
    return false if address.blank?
    address_changed?
  end
end
