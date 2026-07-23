# == Schema Information
#
# Table name: bug_reports
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  body                       :text
#  email                      :text
#  from_name                  :text
#  github_pull_request        :integer
#  is_member                  :boolean          default(FALSE), not null
#  is_paid_organization       :boolean          default(FALSE), not null
#  is_paid_organization_staff :boolean          default(FALSE), not null
#  received_at                :datetime
#  status                     :integer          default("unprioritized"), not null
#  subject                    :text
#  tags                       :text             default([]), not null, is an Array
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  inbound_email_id           :bigint
#  user_id                    :bigint
#
# Indexes
#
#  index_bug_reports_on_inbound_email_id  (inbound_email_id)
#  index_bug_reports_on_tags              (tags) USING gin
#  index_bug_reports_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (inbound_email_id => action_mailbox_inbound_emails.id) ON DELETE => nullify
#
class BugReport < ApplicationRecord
  include PgSearch::Model

  GITHUB_REPO_URL = "https://github.com/bikeindex/bike_index"
  STATUS_ENUM = {unprioritized: 0, ignored: 1, investigate_priority_low: 2,
                 investigate_priority_high: 3, resolved: 4}.freeze

  enum :status, STATUS_ENUM

  belongs_to :user
  belongs_to :inbound_email, class_name: "ActionMailbox::InboundEmail"

  has_many_attached :images

  has_paper_trail only: %i[tags github_pull_request is_member is_paid_organization is_paid_organization_staff]

  pg_search_scope :text_search, against: {subject: "A", email: "A", body: "B"}

  validates :email, presence: true

  before_validation :set_calculated_attributes

  scope :with_tag, ->(tag) { where("tags @> ARRAY[?]::text[]", tag) }

  def self.all_tags
    distinct.pluck(Arel.sql("unnest(tags)")).sort
  end

  def self.normalized_tags(value)
    value = value.to_s.split(/,|\n/) unless value.is_a?(Array)
    value.map { it.to_s.strip.downcase }.reject(&:blank?).uniq.sort
  end

  def tags=(value)
    super(self.class.normalized_tags(value))
  end

  def github_pull_request_url
    return if github_pull_request.blank?

    "#{GITHUB_REPO_URL}/pull/#{github_pull_request}"
  end

  def display_subject
    subject.presence || "(no subject)"
  end

  private

  def set_calculated_attributes
    self.email = EmailNormalizer.normalize(email)
    self.user_id ||= User.fuzzy_email_find(email)&.id
    # booleans snapshot the sender's status at report time - don't re-derive on update
    return unless new_record? && user.present?

    self.is_member = user.member?
    self.is_paid_organization = user.paid_org?
    self.is_paid_organization_staff = user.organization_roles.admin
      .where(organization_id: Organization.paid).limit(1).any?
  end
end
