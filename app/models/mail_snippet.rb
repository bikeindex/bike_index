# == Schema Information
#
# Table name: mail_snippets
#
#  id                    :integer          not null, primary key
#  body                  :text
#  city                  :string
#  is_enabled            :boolean          default(FALSE), not null
#  is_location_triggered :boolean          default(FALSE), not null
#  kind                  :integer          default("custom")
#  latitude              :float
#  longitude             :float
#  proximity_radius      :integer
#  street                :string
#  subject               :text
#  zipcode               :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  country_id            :bigint
#  organization_id       :integer
#  state_id              :bigint
#
class MailSnippet < ApplicationRecord
  include Geocodeable

  KIND_ENUM = {
    custom: 0,
    header: 1,
    welcome: 2,
    after_welcome: 14,
    footer: 3,
    security: 4,
    partial_registration: 6,
    appears_abandoned_notification: 7,
    parked_incorrectly_notification: 8,
    impound_notification: 9,
    impound_claim_approved: 11,
    impound_claim_denied: 12,
    graduated_notification: 10,
    theft_survey_4_2022: 13,
    theft_survey_2023: 15
  }.freeze

  belongs_to :organization
  validates_uniqueness_of :organization_id, scope: [:kind], allow_nil: true
  has_many :public_images, as: :imageable, dependent: :destroy

  scope :enabled, -> { where(is_enabled: true) }
  scope :with_organizations, -> { where.not(organization_id: nil) }
  scope :without_organizations, -> { where(organization_id: nil) }

  enum kind: KIND_ENUM

  after_commit :update_associations

  before_validation :set_calculated_attributes

  attr_accessor :skip_update

  def self.organization_snippets
    {
      header: {emails: "all", description: "Top of email block"},
      welcome: {emails: "finished_registration", description: "Below header"},
      after_welcome: {emails: "finished_registration", description: "After \"Congrats\", in \"Finished registration\""},
      footer: {emails: "all", description: "Above <3 <3 <3 <3 Bike Index Team"},
      partial_registration: {emails: "partial_registration", description: "Above \"Finish it\" button, in email \"Partial registration\""},
      security: {emails: "finished_registration", description: "How to keep your bike safe, in email \"Finished registration\""}
    }.with_indifferent_access.freeze
  end

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  # Will become more complex probably!
  def self.kind_humanized(str)
    str&.humanize
  end

  # TODO: not sure we need this method?
  def self.organization_snippet_kinds
    organization_snippets.keys
  end

  def self.organization_email_for(kind)
    kind = kind&.to_s
    return kind.to_s unless organization_snippet_kinds.include?(kind)
    organization_snippets.dig(kind, :emails)
  end

  def self.organization_emails_with_snippets
    # Worth noting: no snippet is named "finished_registration"
    ParkingNotification.kinds + %w[finished_registration finished_registration_stolen partial_registration
      graduated_notification impound_claim_approved impound_claim_denied]
  end

  def self.organization_message_kinds
    ParkingNotification.kinds + %w[graduated_notification impound_claim_denied impound_claim_approved]
  end

  def self.location_triggered_kinds
    []
  end

  def which_organization_email
    self.class.organization_email_for(kind)
  end

  def in_email?(str)
    which_organization_email == "all" || str.to_s == which_organization_email
  end

  def organization_message?
    self.class.organization_message_kinds.include?(kind)
  end

  # stub for now, but might be more complicated later. Makes it clearer for a form field
  def editable_subject?
    organization_message?
  end

  def location_triggered?
    self.class.location_triggered_kinds.include?(kind)
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def max_body_length
    nil # match mail_snippet method
  end

  def set_calculated_attributes
    self.is_enabled = false if is_enabled && body.blank?
    self.kind ||= "custom"
  end

  def update_associations
    return true if skip_update
    # Because we need to update the organization and make sure mail snippet calculations are included
    # Manually update to ensure that it runs the before save stuff
    organization&.update(updated_at: Time.current)
  end

  private

  def should_be_geocoded?
    false # Currently the only location_triggered variety is set from the organization location
  end
end
