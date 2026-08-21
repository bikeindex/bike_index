require "rails_helper"

RSpec.describe OrganizationSamlConfiguration, type: :model do
  let(:idp_cert) { File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")) }

  describe "factory" do
    let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration) }
    it "is valid and inactive by default" do
      expect(saml_configuration).to be_valid
      expect(saml_configuration.active?).to be_falsey
      expect(saml_configuration.configured?).to be_falsey
      expect(saml_configuration.organization.enabled?("saml_sso")).to be_truthy
    end

    context "active trait" do
      let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :active) }
      it "is valid and configured" do
        expect(saml_configuration).to be_valid
        expect(saml_configuration.configured?).to be_truthy
      end
    end
  end

  describe "validations" do
    let(:saml_configuration) { FactoryBot.build(:organization_saml_configuration, active: true) }
    it "requires idp essentials when active" do
      expect(saml_configuration).to_not be_valid
      expect(saml_configuration.errors.attribute_names).to include(:idp_entity_id, :idp_sso_target_url, :idp_cert)
    end

    it "permits blank idp fields when inactive" do
      saml_configuration.active = false
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

    context "organization without a permitted domain" do
      let(:saml_configuration) { FactoryBot.build(:organization_saml_configuration, :active, organization:) }
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso") }
      it "can't be active" do
        expect(saml_configuration).to_not be_valid
        expect(saml_configuration.errors.full_messages)
          .to include("Organization must have a permitted domain to enable SAML SSO")

        saml_configuration.active = false
        expect(saml_configuration).to be_valid
      end
    end

    context "configured" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: "saml_sso", user_email_domain: "configured.example.com")
      end
      let!(:configured) { FactoryBot.create(:organization_saml_configuration, :active, organization:) }
      let!(:inactive) do
        FactoryBot.create(:organization_saml_configuration, organization: FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: "saml_sso"), idp_entity_id: "https://idp.example.edu/",
          idp_sso_target_url: "https://idp.example.edu/sso", idp_cert: idp_cert)
      end

      it "matches configurations with all IdP essentials" do
        expect(described_class.configured).to include(configured, inactive)
      end

      it "matches configured inactive configurations" do
        expect(described_class.configured_inactive).to eq [inactive]
      end
    end

    context "name_id_format" do
      it "permits a known format, and rejects anything else" do
        saml_configuration.assign_attributes(idp_entity_id: "https://idp.example.edu/",
          idp_sso_target_url: "https://idp.example.edu/sso", idp_cert:)

        saml_configuration.name_id_format = OrganizationSamlConfiguration::NAME_ID_FORMATS["persistent"]
        expect(saml_configuration).to be_valid

        saml_configuration.name_id_format = "persistent"
        expect(saml_configuration).to_not be_valid
        expect(saml_configuration.errors.attribute_names).to include(:name_id_format)
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
