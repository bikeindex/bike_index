class MailSnippet < ActiveRecord::Base
  validates_presence_of :name

  belongs_to :organization
  validates_uniqueness_of :organization_id, scope: [:name], allow_nil: true

  scope :enabled, -> { where(is_enabled: true) }
  scope :location_triggered, -> { where(is_location_triggered: true) }
  scope :with_organizations, -> { where.not(organization_id: nil) }
  scope :without_organizations, -> { where(organization_id: nil) }

  geocoded_by :address
  after_validation :geocode, if: lambda { is_location_triggered && address.present? }

  class << self
    def organization_snippet_types
      {
        header: 'Top of email block',
        welcome: 'Below header',
        security: 'How keep you bike safe, included in finished registration email'
      }
    end

    def matching_opts(opts)
      return nil unless opts[:mailer_method].match('ownership_invitation_email')
      return nil unless opts[:bike] && opts[:bike].stolen && opts[:bike].current_stolen_record
      stolen_record = opts[:bike].current_stolen_record
      return nil unless stolen_record.present? && stolen_record.latitude.present?
      enabled.location_triggered.detect { |s| s.distance_to(stolen_record) <= s.proximity_radius }
    end
  end
end
