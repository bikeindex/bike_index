# == Schema Information
#
# Table name: sso_identities
# Database name: primary
#
#  id              :bigint           not null, primary key
#  email           :string
#  last_sign_in_at :datetime
#  name_id_format  :string
#  provider        :string
#  uid             :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :bigint
#  user_id         :bigint
#
# Indexes
#
#  index_sso_identities_on_organization_id                       (organization_id)
#  index_sso_identities_on_organization_id_and_provider_and_uid  (organization_id,provider,uid) UNIQUE
#  index_sso_identities_on_user_id                               (user_id)
#
class SsoIdentity < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: {scope: %i[organization_id provider]}

  before_validation :set_calculated_attributes

  def self.for(organization:, provider:, uid:)
    find_by(organization_id: organization.id, provider:, uid:)
  end

  private

  def set_calculated_attributes
    self.email = EmailNormalizer.normalize(email)
  end
end
