# == Schema Information
#
# Table name: bug_reports
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  body                       :text
#  email                      :text
#  github_pull_request        :integer
#  is_member                  :boolean          default(FALSE), not null
#  is_paid_organization       :boolean          default(FALSE), not null
#  is_paid_organization_staff :boolean          default(FALSE), not null
#  subject                    :text
#  tags                       :text             default([]), not null, is an Array
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  user_id                    :bigint
#
# Indexes
#
#  index_bug_reports_on_tags     (tags) USING gin
#  index_bug_reports_on_user_id  (user_id)
#
class BugReport < ApplicationRecord
  include PgSearch::Model

  GITHUB_REPO_URL = "https://github.com/bikeindex/bike_index"

  belongs_to :user, optional: true

  has_many_attached :attachments

  has_paper_trail only: %i[tags github_pull_request is_member is_paid_organization is_paid_organization_staff]

  pg_search_scope :text_search, against: {subject: "A", email: "A", body: "B"}

  validates :email, presence: true

  before_validation :set_calculated_attributes

  scope :with_tag, ->(tag) { where("tags @> ARRAY[?]::text[]", tag) }

  def self.all_tags
    distinct.pluck(Arel.sql("unnest(tags)")).sort
  end

  def github_pull_request_url
    return if github_pull_request.blank?

    "#{GITHUB_REPO_URL}/pull/#{github_pull_request}"
  end

  private

  def set_calculated_attributes
    self.email = EmailNormalizer.normalize(email)
    self.tags = tags.map { it.strip.downcase }.reject(&:blank?).uniq.sort
    self.user_id ||= User.fuzzy_email_find(email)&.id
    return if user.blank?

    self.is_member = user.member?
    self.is_paid_organization = user.paid_org?
    self.is_paid_organization_staff = user.organization_roles.admin
      .where(organization_id: Organization.paid).limit(1).any?
  end
end
