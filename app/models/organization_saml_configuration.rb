# == Schema Information
#
# Table name: organization_saml_configurations
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  email_attribute_name :string
#  active               :boolean          default(FALSE), not null
#  idp_cert             :text
#  idp_cert_fingerprint :string
#  idp_cert_multi       :text
#  idp_slo_target_url   :string
#  idp_sso_target_url   :string
#  name_id_format       :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  idp_entity_id        :string
#  organization_id      :bigint           not null
#
# Indexes
#
#  index_organization_saml_configurations_on_organization_id  (organization_id) UNIQUE
#
class OrganizationSamlConfiguration < ApplicationRecord
  PROVIDER = "saml"
  # Asserted attribute that carries the user's email, when it isn't the NameID
  DEFAULT_EMAIL_ATTRIBUTE = "urn:oid:0.9.2342.19200300.100.1.3"
  # NameIDPolicy for the AuthnRequest; blank omits the element
  NAME_ID_FORMATS = {
    "persistent" => "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent",
    "transient" => "urn:oasis:names:tc:SAML:2.0:nameid-format:transient",
    "emailAddress" => "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
    "unspecified" => "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
  }.freeze
  CONFIGURED_ATTRIBUTES = %i[idp_entity_id idp_sso_target_url idp_cert].freeze

  belongs_to :organization

  validates :organization_id, presence: true, uniqueness: true
  validates :idp_entity_id, :idp_sso_target_url, :idp_cert, presence: true, if: :active?
  validates :name_id_format, inclusion: {in: NAME_ID_FORMATS.values}, allow_blank: true
  validate :idp_certificates_parseable
  validate :organization_claims_a_domain, if: :active?

  before_validation :set_calculated_attributes
  after_commit :update_organization

  def self.format_cert(cert)
    return nil if cert.blank?
    OneLogin::RubySaml::Utils.format_cert(cert)
  end

  def configured?
    organization&.user_email_domain.present? && CONFIGURED_ATTRIBUTES.all? { |attribute| self[attribute].present? }
  end

  def email_attribute
    email_attribute_name.presence || DEFAULT_EMAIL_ATTRIBUTE
  end

  # PEM-normalized certs ruby-saml understands (primary, plus rotation-overlap cert)
  def idp_certificates
    [idp_cert, idp_cert_multi].filter_map { |cert| self.class.format_cert(cert) }
  end

  private

  def set_calculated_attributes
    %i[idp_entity_id idp_sso_target_url idp_slo_target_url idp_cert idp_cert_fingerprint
      idp_cert_multi email_attribute_name name_id_format].each do |attribute|
      self[attribute] = self[attribute].presence&.strip
    end
  end

  def idp_certificates_parseable
    %i[idp_cert idp_cert_multi].each do |attribute|
      next if self[attribute].blank?
      OpenSSL::X509::Certificate.new(self.class.format_cert(self[attribute]))
    rescue OpenSSL::X509::CertificateError
      errors.add(attribute, "is not a valid X.509 certificate")
    end
  end

  # Every assertion is authorized against the domain, so without one this config can't sign anyone in
  def organization_claims_a_domain
    return if organization&.user_email_domain.present?

    errors.add(:base, "Organization must have a permitted domain to enable SAML SSO")
  end

  def update_organization
    organization&.update(updated_at: Time.current)
  end
end
