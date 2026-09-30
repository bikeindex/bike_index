# == Schema Information
#
# Table name: organization_signups
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  address                    :jsonb            not null
#  email                      :string
#  email_confirmation_sent_at :datetime
#  email_confirmation_token   :string
#  email_confirmed_at         :datetime
#  id_token                   :string           not null
#  kind                       :integer
#  likely_spam                :boolean          default(FALSE), not null
#  name                       :string
#  phone                      :string
#  publicly_visible           :boolean          default(TRUE), not null
#  return_to                  :string
#  website                    :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  organization_id            :bigint
#
# Indexes
#
#  index_organization_signups_on_id_token         (id_token) UNIQUE
#  index_organization_signups_on_organization_id  (organization_id)
#
class OrganizationSignup < ApplicationRecord
  # How long a signup resumes by token, and so how long its emailed link works
  TOKEN_EXPIRATION = 30.days
  # The state (or region) isn't here: which one a country has is the form's to decide
  REQUIRED_ADDRESS_ATTRS = %w[street city postal_code country_id].freeze

  enum :kind, Organization::KIND_ENUM

  belongs_to :organization

  before_validation :set_calculated_attributes
  before_create { self.id_token = SecurityTokenizer.new_token }

  scope :unexpired, -> { where("created_at >= ?", Time.current - TOKEN_EXPIRATION) }

  def expired? = created_at < Time.current - TOKEN_EXPIRATION

  def email_confirmed? = email_confirmed_at.present?

  def details_completed? = REQUIRED_ADDRESS_ATTRS.all? { address[it].present? }

  # A blank token reads as expired - token_time floors at EARLIEST_TOKEN_TIME
  def email_confirmation_token_expired?
    SecurityTokenizer.token_time(email_confirmation_token) < Time.current - TOKEN_EXPIRATION
  end

  def address_record = AddressRecord.new(address)

  private

  def set_calculated_attributes
    self.name = name&.strip
    self.website = website&.strip.presence
  end
end
