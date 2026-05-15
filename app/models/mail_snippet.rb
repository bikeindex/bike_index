# == Schema Information
#
# Table name: mail_snippets
# Database name: primary
#
#  id                :integer          not null, primary key
#  body              :text
#  is_enabled        :boolean          default(FALSE), not null
#  kind              :integer          default("custom")
#  subject           :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  doorkeeper_app_id :bigint
#  organization_id   :integer
#
class MailSnippet < ApplicationRecord
  has_paper_trail only: %i[body is_enabled kind subject]

  PAPER_TRAIL_TRACKING_STARTED_AT = Time.zone.local(2026, 4, 1).freeze

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
    other_parking_notification: 18,
    impound_notification: 9,
    impound_claim_approved: 11,
    impound_claim_denied: 12,
    graduated_notification: 10,
    theft_survey_4_2022: 13,
    theft_survey_2023: 15,
    stolen_notification_oauth: 16,
    newsletter: 17,
    tempo: 19
  }.freeze

  enum :kind, KIND_ENUM

  belongs_to :organization
  belongs_to :doorkeeper_app, class_name: "Doorkeeper::Application"

  has_many :public_images, as: :imageable, dependent: :destroy

  validates_uniqueness_of :organization_id, scope: [:kind], allow_nil: true
  validates_uniqueness_of :doorkeeper_app_id, scope: [:kind], allow_nil: true

  attr_accessor :skip_update

  after_commit :update_associations

  before_validation :set_calculated_attributes

  scope :enabled, -> { where(is_enabled: true) }
  scope :with_organizations, -> { where.not(organization_id: nil) }
  scope :without_organizations, -> { where(organization_id: nil) }

  class << self
    def organization_snippets
      {
        header: {emails: "all", description: "Top of email block"},
        welcome: {emails: "finished_registration", description: "Below header"},
        after_welcome: {emails: "finished_registration", description: "After \"Congrats\", in \"Finished registration\""},
        footer: {emails: "all", description: "Above <3 <3 <3 <3 Bike Index Team"},
        partial_registration: {emails: "partial_registration", description: "Above \"Finish it\" button, in email \"Partial registration\""},
        security: {emails: "finished_registration", description: "How to keep your bike safe, in email \"Finished registration\""}
      }.with_indifferent_access.freeze
    end

    def kinds
      KIND_ENUM.keys.map(&:to_s)
    end

    # Will become more complex probably!
    def kind_humanized(str)
      str&.humanize
    end

    # TODO: not sure we need this method?
    def organization_snippet_kinds
      organization_snippets.keys
    end

    def organization_snippets_in_all
      organization_snippets.map do |k, v|
        next unless v[:emails] == "all"

        k.to_s
      end.compact
    end

    def organization_email_for(kind)
      kind = kind&.to_s
      return kind.to_s unless organization_snippet_kinds.include?(kind)

      organization_snippets.dig(kind, :emails)
    end

    def organization_emails_with_snippets
      # Worth noting: no snippet is named "finished_registration"
      ParkingNotification.kinds + %w[finished_registration finished_registration_stolen partial_registration
        graduated_notification impound_claim_approved impound_claim_denied]
    end

    def organization_message_kinds
      ParkingNotification.kinds + %w[graduated_notification impound_claim_denied impound_claim_approved]
    end

    # With `time`, reifies the snippet via paper_trail (including destroyed ones).
    # Snippets created before PAPER_TRAIL_TRACKING_STARTED_AT have no recorded create
    # version, so they fall back to the live snippet when paper_trail has no relevant
    # version to return.
    def for_organization(organization_id:, kind:, time: nil)
      snippet = where(organization_id:, kind:).first

      if time.present?
        snippet = if snippet.blank?
          reify_destroyed_at(organization_id:, kind:, time:)
        elsif snippet.created_at >= PAPER_TRAIL_TRACKING_STARTED_AT
          snippet.paper_trail.version_at(time)
        else
          snippet.paper_trail.version_at(time) || snippet
        end
      end

      snippet if snippet&.is_enabled
    end

    private

    # Reify a snippet that no longer exists, by finding the destroy version after `time`
    # and walking back to the version active at `time`.
    def reify_destroyed_at(organization_id:, kind:, time:)
      return nil unless KIND_ENUM.key?(kind.to_sym)

      destroy_version = PaperTrail::Version
        .where(item_type: name, event: "destroy")
        .where("object @> ?", {organization_id:, kind: kind.to_s}.to_json)
        .where("created_at > ?", time)
        .order(:created_at).first
      return nil if destroy_version.blank?

      next_version = PaperTrail::Version
        .where(item_type: name, item_id: destroy_version.item_id)
        .where("created_at > ?", time)
        .order(:created_at).first

      next_version&.reify
    end
  end

  def which_organization_email
    self.class.organization_email_for(kind)
  end

  def in_email?(str, exclude_all: false)
    unless exclude_all
      return true if which_organization_email == "all"
    end

    str.to_s == which_organization_email
  end

  def organization_message?
    self.class.organization_message_kinds.include?(kind)
  end

  # stub for now, but might be more complicated later. Makes it clearer for a form field
  def editable_subject?
    organization_message?
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
    self.subject = Binxtils::InputNormalizer.string(subject)
  end

  def update_associations
    return true if skip_update

    # Because we need to update the organization and make sure mail snippet calculations are included
    # Manually update to ensure that it runs the before save stuff
    organization&.update(updated_at: Time.current)
  end
end
