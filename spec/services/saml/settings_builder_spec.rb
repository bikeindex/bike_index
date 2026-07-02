require "rails_helper"

RSpec.describe Saml::SettingsBuilder do
  let(:sp_cert) { File.read(Rails.root.join("spec/fixtures/saml/sp_cert.pem")) }
  let(:sp_key) { File.read(Rails.root.join("spec/fixtures/saml/sp_key.pem")) }
  let(:idp_cert) { File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")) }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso") }
  let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled, organization:) }
  subject(:settings) { described_class.build(saml_configuration) }

  around do |example|
    original = ENV.values_at("SAML_SP_CERTIFICATE", "SAML_SP_PRIVATE_KEY", "BASE_URL")
    ENV["SAML_SP_CERTIFICATE"] = sp_cert
    ENV["SAML_SP_PRIVATE_KEY"] = sp_key
    ENV["BASE_URL"] = "https://bikeindex.org"
    example.run
    ENV["SAML_SP_CERTIFICATE"], ENV["SAML_SP_PRIVATE_KEY"], ENV["BASE_URL"] = original
  end

  it "sets slug-scoped SP urls" do
    expect(settings.sp_entity_id).to eq "https://bikeindex.org/sso/#{organization.to_param}/metadata"
    expect(settings.assertion_consumer_service_url).to eq "https://bikeindex.org/sso/#{organization.to_param}/callback"
    expect(settings.assertion_consumer_service_binding).to eq Saml::SettingsBuilder::HTTP_POST
  end

  it "loads the SP keypair from ENV" do
    expect(settings.certificate).to eq sp_cert
    expect(settings.private_key).to eq sp_key
  end

  it "carries the IdP config" do
    expect(settings.idp_entity_id).to eq saml_configuration.idp_entity_id
    expect(settings.idp_sso_service_url).to eq saml_configuration.idp_sso_target_url
    expect(settings.idp_cert).to include("BEGIN CERTIFICATE")
  end

  it "enforces signed assertions + SHA-256" do
    expect(settings.security[:want_assertions_signed]).to be true
    expect(settings.security[:authn_requests_signed]).to be true
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
