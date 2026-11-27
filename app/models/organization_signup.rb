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
#  email_confirmations_sent   :integer          default(0), not null
#  email_confirmed_at         :datetime
#  id_token                   :string           not null
#  kind                       :integer
#  likely_spam                :boolean          default(FALSE), not null
#  name                       :string
#  phone                      :string
#  pos_kind                   :integer
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
  # How long a signup resumes by token, and its emailed link works, after the latest email
  TOKEN_EXPIRATION = 30.days
  # The state (or region) isn't here: which one a country has is the form's to decide.
  # Nor is the postal code, which only some countries have
  REQUIRED_ADDRESS_ATTRS = %w[street city country_id].freeze
  # Only blatantly wrong ones - UI::Forms::Input has these as patterns
  DETAIL_FORMATS = {website: Urlifyer::WEBSITE_REGEX, phone: Phonifyer::REGEX, postal_code: Geocodeable::POSTAL_CODE_REGEX}.freeze

  enum :kind, Organization::KIND_ENUM
  # What a shop said it uses, rather than Organization#pos_kind's integration status
  enum :pos_kind, {lightspeed_pos: 0, ascend_pos: 1, shopify_pos: 2, other_or_none_pos: 3}

  belongs_to :organization

  before_validation :set_calculated_attributes
  before_create { self.id_token = SecurityTokenizer.new_token }

  scope :unexpired, -> { where("GREATEST(created_at, email_confirmation_sent_at) >= ?", Time.current - TOKEN_EXPIRATION) }

  def email_confirmed? = email_confirmed_at.present?

  def details_completed? = address_completed? && malformed_details.none?

  def address_completed?
    REQUIRED_ADDRESS_ATTRS.all? { address[it].present? } &&
      (address["postal_code"].present? || Country.without_postal_code_ids.include?(address["country_id"].to_i))
  end

  def malformed_details
    {website:, phone:, postal_code: address["postal_code"]}
      .filter_map { |attribute, value| attribute if value.present? && !value.match?(DETAIL_FORMATS[attribute]) }
  end

  # A resend reuses the token, so it lasts from the latest email - which promises that long
  def email_confirmation_token_expired?
    email_confirmation_token.blank? || email_confirmation_sent_at.to_i < (Time.current - TOKEN_EXPIRATION).to_i
  end

  def address_record = AddressRecord.new(address)

  private

  # The organization would strip markup from the name anyway, so the steps and the email show what it'll be called
  def set_calculated_attributes
    self.name = Organization.sanitize_name(name) if name.present?
    self.website = normalized(website)
    self.phone = normalized(phone)
    self.address = address.merge("postal_code" => normalized(address["postal_code"])).compact
  end

  # A pasted non-breaking space is whitespace to the browser's pattern, but not to Ruby's \s
  def normalized(value) = value&.squish.presence
end
