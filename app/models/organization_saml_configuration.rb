# == Schema Information
#
# Table name: organization_saml_configurations
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  allow_idp_initiated  :boolean          default(FALSE)
#  email_attribute_name :string
#  enabled              :boolean          default(FALSE)
#  idp_cert             :text
#  idp_cert_fingerprint :string
#  idp_cert_multi       :text
#  idp_slo_target_url   :string
#  idp_sso_target_url   :string
#  name_id_format       :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  idp_entity_id        :string
#  organization_id      :bigint
#
# Indexes
#
#  index_organization_saml_configurations_on_organization_id  (organization_id) UNIQUE
#
class OrganizationSamlConfiguration < ApplicationRecord
  PROVIDER = "saml"
  # Asserted attribute that carries the user's email, when it isn't the NameID
  DEFAULT_EMAIL_ATTRIBUTE = "urn:oid:0.9.2342.19200300.100.1.3"

  belongs_to :organization

  validates :organization_id, presence: true, uniqueness: true
  validates :idp_entity_id, :idp_sso_target_url, :idp_cert, presence: true, if: :enabled?
  validate :idp_certificates_parseable

  before_validation :set_calculated_attributes
  after_commit :update_organization

  def self.format_cert(cert)
    return nil if cert.blank?
    OneLogin::RubySaml::Utils.format_cert(cert)
  end

  # Ready to drive a live login: enabled and the IdP essentials are present
  def configured?
    enabled? && idp_entity_id.present? && idp_sso_target_url.present? && idp_cert.present?
  end

  # Single Logout additionally needs the IdP's logout endpoint
  def slo_configured?
    configured? && idp_slo_target_url.present?
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

  def update_organization
    organization&.update(updated_at: Time.current)
  end
end
