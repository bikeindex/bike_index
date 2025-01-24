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
  belongs_to :creator, class_name: "User"

  validates_presence_of :creator_id
  validates_presence_of :domain
  validates_uniqueness_of :domain
  validate :domain_is_expected_format

  def domain_is_expected_format
    self.domain = domain.strip

    errors.add(:domain, "Must start with @") unless domain.start_with?("@")
    errors.add(:domain, "Must include a .") unless domain.match?(/\./)
  end
end
