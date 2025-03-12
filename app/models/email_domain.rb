# frozen_string_literal: true

# == Schema Information
#
# Table name: email_domains
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  domain     :string
#  status     :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :bigint
#
# Indexes
#
#  index_email_domains_on_creator_id  (creator_id)
#
class EmailDomain < ApplicationRecord
  include StatusHumanizable

  BIKE_MAX_COUNT = 2
  EMAIL_MIN_COUNT = 200
  STATUS_ENUM = {permitted: 0, pending_ban: 1, banned: 2}

  acts_as_paranoid

  enum :status, STATUS_ENUM

  belongs_to :creator, class_name: "User"

  validates_presence_of :creator_id
  validates_presence_of :domain
  validates_uniqueness_of :domain
  validate :domain_is_expected_format
  validate :domain_is_not_contained_in_existing, on: :create

  class << self
    # NOTE: This is called in the admin controller on create, but not if done in console!
    def allow_creation?(str)
      domain = str.strip
      return true unless /\./.match?(domain)

      !too_few_emails?(domain) && !too_many_bikes?(domain) && no_valid_organization_roles?(domain)
    end

    def no_valid_organization_roles?(domain)
      org_ids = OrganizationRole.unscoped.where("invited_email ILIKE ?", "%#{domain}").pluck(:organization_id)
      Organization.approved.where(id: org_ids).none?
    end

    def too_few_emails?(domain)
      User.unscoped.matching_domain(domain).count < EMAIL_MIN_COUNT
    end

    def too_many_bikes?(domain)
      Bike.unscoped.where("owner_email ILIKE ?", "%#{domain}").count > BIKE_MAX_COUNT
    end

    def status_humanized(str)
      str.humanize
    end
  end

  def status_humanized
    self.class.status_humanized(status)
  end

  def domain_is_expected_format
    self.domain = domain.strip

    errors.add(:domain, "Must include a .") unless domain.match?(/\./)
  end

  # TODO: This is really inefficient
  def domain_is_not_contained_in_existing
    broader_ban = EmailDomain.pluck(:domain).detect { |d| domain.match?(d) }
    return if broader_ban.blank?

    errors.add(:domain, "already banned: '#{broader_ban}'")
  end
end
