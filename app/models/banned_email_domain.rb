# frozen_string_literal: true

# == Schema Information
#
# Table name: banned_email_domains
#
#  id         :bigint           not null, primary key
#  domain     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :bigint
#
class BannedEmailDomain < ApplicationRecord
  BIKE_MAX_COUNT = 2
  EMAIL_MIN_COUNT = 500

  belongs_to :creator, class_name: "User"

  validates_presence_of :creator_id
  validates_presence_of :domain
  validates_uniqueness_of :domain
  validate :domain_is_expected_format
  validate :likely_new_spam_domain, on: :create

  def self.likely_new_spam_domain?(domain)
    !too_few_emails?(domain) && !too_many_bikes?(domain)
  end

  def self.too_few_emails?(domain)
    User.unscoped.matching_domain(domain).count < EMAIL_MIN_COUNT
  end

  def self.too_many_bikes?(domain)
    Bike.unscoped.where("owner_email ILIKE ?", "%#{domain}").count > BIKE_MAX_COUNT
  end

  def domain_is_expected_format
    self.domain = domain.strip

    errors.add(:domain, "Must start with @") unless domain.start_with?("@")
    errors.add(:domain, "Must include a .") unless domain.match?(/\./)
  end

  def likely_new_spam_domain
    base_message = "Doesn't seem like a new spam email domain - "
    if self.class.too_many_bikes?(domain)
      errors.add(:base, "#{base_message} too many bikes match the domain")
    elsif self.class.too_few_emails?(domain)
      errors.add(:base, "#{base_message} not enough emails match the domain")
    end
  end
end
