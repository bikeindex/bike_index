class MailSnippet < ActiveRecord::Base
  validates_presence_of :name

  belongs_to :organization
  validates_uniqueness_of :organization_id, scope: [:name], allow_nil: true
  has_many :public_images, as: :imageable, dependent: :destroy

  scope :enabled, -> { where(is_enabled: true) }
  scope :location_triggered, -> { where(is_location_triggered: true) }
  scope :with_organizations, -> { where.not(organization_id: nil) }
  scope :without_organizations, -> { where(organization_id: nil) }

  geocoded_by :address
  after_validation :geocode, if: lambda { is_location_triggered && address.present? }

  class << self
    def organization_snippets
      {
        header: 'Top of email block',
        welcome: 'Below header',
        security: 'How to keep your bike safe, in email "finished registration"'
      }.as_json
    end

    def organization_snippet_types
      organization_snippets.keys
    end

    def matching_opts(opts)
      return nil unless opts[:mailer_method].match('ownership_invitation_email')
      return nil unless opts[:bike] && opts[:bike].stolen && opts[:bike].current_stolen_record
      stolen_record = opts[:bike].current_stolen_record
      return nil unless stolen_record.present? && stolen_record.latitude.present?
      enabled.location_triggered.detect { |s| s.distance_to(stolen_record) <= s.proximity_radius }
    end
  end

  before_save :disable_if_blank
  def disable_if_blank
    self.is_enabled = false if is_enabled && body.blank?
  end
end
