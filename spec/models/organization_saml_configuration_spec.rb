require "rails_helper"

RSpec.describe OrganizationSamlConfiguration, type: :model do
  let(:idp_cert) { File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")) }

  describe "factory" do
    let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration) }
    it "is valid and disabled by default" do
      expect(saml_configuration).to be_valid
      expect(saml_configuration.enabled?).to be_falsey
      expect(saml_configuration.configured?).to be_falsey
      expect(saml_configuration.organization.enabled?("saml_sso")).to be_truthy
    end

    context "enabled trait" do
      let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled) }
      it "is valid and configured" do
        expect(saml_configuration).to be_valid
        expect(saml_configuration.configured?).to be_truthy
      end
    end
  end

  describe "#slo_configured?" do
    it "is false when configured but missing the IdP logout endpoint" do
      saml_configuration = FactoryBot.create(:organization_saml_configuration, :enabled)
      expect(saml_configuration.slo_configured?).to be_falsey
    end

    it "is true once the IdP logout endpoint is present" do
      saml_configuration = FactoryBot.create(:organization_saml_configuration, :enabled, :with_slo)
      expect(saml_configuration.slo_configured?).to be_truthy
    end
  end

  describe "validations" do
    let(:saml_configuration) { FactoryBot.build(:organization_saml_configuration, enabled: true) }
    it "requires idp essentials when enabled" do
      expect(saml_configuration).to_not be_valid
      expect(saml_configuration.errors.attribute_names).to include(:idp_entity_id, :idp_sso_target_url, :idp_cert)
    end

    it "permits blank idp fields when disabled" do
      saml_configuration.enabled = false
      expect(saml_configuration).to be_valid
    end

    context "uniqueness per organization" do
      let!(:existing) { FactoryBot.create(:organization_saml_configuration) }
      it "is one per organization" do
        duplicate = FactoryBot.build(:organization_saml_configuration, organization: existing.organization)
        expect(duplicate).to_not be_valid
        expect(duplicate.errors.attribute_names).to include(:organization_id)
      end
    end

    context "invalid certificate" do
      it "adds an error" do
        saml_configuration.assign_attributes(idp_entity_id: "https://idp.example.edu/",
          idp_sso_target_url: "https://idp.example.edu/sso", idp_cert: "not a cert")
        expect(saml_configuration).to_not be_valid
        expect(saml_configuration.errors.attribute_names).to include(:idp_cert)
      end
    end
  end

  describe "#idp_certificates" do
    let(:saml_configuration) { FactoryBot.build(:organization_saml_configuration, idp_cert: bare_cert) }
    # bare base64 (no PEM header), as some IdP admins paste it
    let(:bare_cert) { idp_cert.gsub(/-----(BEGIN|END) CERTIFICATE-----/, "").gsub(/\s+/, "") }
    it "normalizes to PEM" do
      certs = saml_configuration.idp_certificates
      expect(certs.length).to eq 1
      expect(certs.first).to include("BEGIN CERTIFICATE")
      expect { OpenSSL::X509::Certificate.new(certs.first) }.to_not raise_error
    end

    context "with a rotation-overlap cert" do
      let(:saml_configuration) { FactoryBot.build(:organization_saml_configuration, idp_cert:, idp_cert_multi: idp_cert) }
      it "returns both" do
        expect(saml_configuration.idp_certificates.length).to eq 2
      end
    end
  end

  describe "#email_attribute" do
    let(:saml_configuration) { FactoryBot.build(:organization_saml_configuration) }
    it "defaults to the standard email oid" do
      expect(saml_configuration.email_attribute).to eq OrganizationSamlConfiguration::DEFAULT_EMAIL_ATTRIBUTE
    end
    it "uses the configured attribute when present" do
      saml_configuration.email_attribute_name = "email"
      expect(saml_configuration.email_attribute).to eq "email"
    end
  end

  describe "after_commit" do
    let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration) }
    it "touches the organization" do
      organization = saml_configuration.organization
      expect do
        saml_configuration.update(idp_entity_id: "https://idp.example.edu/")
      end.to(change { organization.reload.updated_at })
    end
  end
end
