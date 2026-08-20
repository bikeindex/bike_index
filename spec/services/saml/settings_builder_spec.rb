require "rails_helper"

RSpec.describe Saml::SettingsBuilder, :saml_env do
  let(:idp_cert) { File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")) }
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features,
      enabled_feature_slugs: "saml_sso", user_email_domain: "example.edu")
  end
  let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled, organization:) }
  subject(:settings) { described_class.build(saml_configuration) }

  it "sets slug-scoped SP urls" do
    expect(settings.sp_entity_id).to eq "https://bikeindex.org/sso/#{organization.to_param}/metadata"
    expect(settings.assertion_consumer_service_url).to eq "https://bikeindex.org/sso/#{organization.to_param}/callback"
    expect(settings.assertion_consumer_service_binding).to eq Saml::SettingsBuilder::HTTP_POST
  end

  # routes.rb has no /slo, so advertising one hands the IdP a URL that 404s
  it "advertises no SLO endpoint" do
    expect(settings.single_logout_service_url).to be_blank
    expect(OneLogin::RubySaml::Metadata.new.generate(settings)).to_not include("SingleLogoutService")
  end

  it "loads the SP keypair from ENV" do
    expect(settings.certificate).to eq sp_cert
    expect(settings.private_key).to eq sp_key
  end

  context "with a base64-encoded keypair in ENV" do
    let(:sp_cert) { Base64.strict_encode64(sp_cert_pem) }
    let(:sp_key) { Base64.strict_encode64(sp_key_pem) }

    it "decodes both back to PEM" do
      expect(settings.certificate).to eq sp_cert_pem
      expect(settings.private_key).to eq sp_key_pem
    end
  end

  it "carries the IdP config" do
    expect(settings.idp_entity_id).to eq saml_configuration.idp_entity_id
    expect(settings.idp_sso_service_url).to eq saml_configuration.idp_sso_target_url
    expect(settings.idp_cert).to include("BEGIN CERTIFICATE")
  end

  it "enforces signed assertions + SHA-256, and offers an encryption key" do
    expect(settings.security[:want_assertions_signed]).to be true
    expect(settings.security[:authn_requests_signed]).to be true
    expect(settings.security[:want_assertions_encrypted]).to be true
    expect(settings.security[:digest_method]).to eq XMLSecurity::Document::SHA256
    expect(settings.security[:signature_method]).to eq XMLSecurity::Document::RSA_SHA256
  end

  context "with a rotation-overlap cert" do
    let(:saml_configuration) do
      FactoryBot.create(:organization_saml_configuration, :enabled, organization:, idp_cert_multi: idp_cert)
    end
    it "uses idp_cert_multi for signing" do
      expect(settings.idp_cert_multi[:signing].length).to eq 2
    end
  end
end
