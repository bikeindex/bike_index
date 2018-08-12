class MailSnippet < ActiveRecord::Base
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

  geocoded_by :address
  after_validation :geocode, if: lambda { is_location_triggered && address.present? }
  after_commit :update_organization

  before_validation :set_calculated_attributes

  def self.organization_snippets
    {
      header: "Top of email block",
      welcome: "Below header",
      footer: "Above <3 <3 <3 <3 Bike Index Team",
      security: "How to keep your bike safe, in email \"finished registration\"",
      abandoned_bike: "Geocoded abandoned bike email"
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
    organization && organization.update_attributes(updated_at: Time.now)
  end
end
