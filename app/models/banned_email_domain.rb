# frozen_string_literal: true

# == Schema Information
#
# Table name: banned_email_domains
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  domain     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :bigint
#
class BannedEmailDomain < ApplicationRecord
  BIKE_MAX_COUNT = 2
  EMAIL_MIN_COUNT = 500

  acts_as_paranoid

  belongs_to :creator, class_name: "User"

  validates_presence_of :creator_id
  validates_presence_of :domain
  validates_uniqueness_of :domain
  validate :domain_is_expected_format
  class << self
    # NOTE: This is called in the admin controller on create, but not if done in console!
    def allow_creation?(str)
      domain = str.strip
      return true unless /\./.match?(domain)

      return false

      !too_few_emails?(domain) && !too_many_bikes?(domain) && no_valid_memberships?(domain)
    end

    def no_valid_memberships?(domain)
      org_ids = Membership.unscoped.where("invited_email ILIKE ?", "%#{domain}").pluck(:organization_id)
      pp org_ids
      Organization.approved.where(id: org_ids).none?
    end

    def too_few_emails?(domain)
      User.unscoped.matching_domain(domain).count < EMAIL_MIN_COUNT
    end

    def too_many_bikes?(domain)
      Bike.unscoped.where("owner_email ILIKE ?", "%#{domain}").count > BIKE_MAX_COUNT
    end
  end

  def domain_is_expected_format
    self.domain = domain.strip

    errors.add(:domain, "Must include a .") unless domain.match?(/\./)
  end
end
