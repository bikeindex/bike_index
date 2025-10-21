require "rails_helper"

RSpec.describe BikeServices::Builder do
  let(:b_param_params) { {} }
  let(:b_param) { BParam.new(params: b_param_params) }
  let(:organization) { FactoryBot.create(:organization) }

  describe "build" do
    let(:bike) { described_class.build(b_param) }
    it "builds it" do
      expect(bike.status).to eq "status_with_owner"
      expect(bike.id).to be_blank
    end
    context "status impounded" do
      let(:b_param_params) { {bike: {status: "status_impounded"}} }
      it "is abandoned" do
        expect(b_param.status).to eq "status_impounded"
        expect(b_param.impound_attrs).to be_blank
        expect(bike.id).to be_blank
        impound_record = bike.impound_records.last
        expect(impound_record).to be_present
        expect(impound_record.kind).to eq "found"
        expect(bike.status_humanized).to eq "found"
      end
      context "with impound attrs" do
        let(:time) { Time.current - 12.hours }
        let(:b_param_params) { {bike: {status: "status_with_owner"}, impound_record: {impounded_at: time}} }
        it "is abandoned" do
          expect(b_param.status).to eq "status_impounded"
          expect(b_param.impound_attrs).to be_present
          expect(bike.id).to be_blank
          impound_record = bike.impound_records.last
          expect(impound_record).to be_present
          expect(impound_record.kind).to eq "found"
          expect(impound_record.impounded_at).to be_within(1).of time
          expect(bike.status_humanized).to eq "found"
        end
      end
    end
    context "status stolen" do
      let(:b_param_params) { {bike: {status: "status_stolen"}} }
      it "is stolen" do
        expect(b_param).to be_valid
        expect(b_param.status).to eq "status_stolen"
        expect(b_param.stolen_attrs).to be_blank
        expect(bike.status).to eq "status_stolen"
        expect(bike.id).to be_blank
        expect(bike.stolen_records.last).to be_present
      end
      context "legacy_stolen" do
        let(:b_param_params) { {bike: {stolen: true}} }
        it "is stolen" do
          expect(b_param).to be_valid
          expect(b_param.status).to eq "status_stolen"
          expect(b_param.stolen_attrs).to be_blank
          expect(bike.status).to eq "status_stolen"
          expect(bike.id).to be_blank
          expect(bike.stolen_records.last).to be_present
        end
      end
    end
    context "with id" do
      let(:b_param) { FactoryBot.create(:b_param, params: b_param_params) }
      it "includes ID" do
        expect(b_param).to be_valid
        expect(bike.status).to eq "status_with_owner"
        expect(bike.id).to be_blank
        expect(bike.b_param_id).to eq b_param.id
        expect(bike.b_param_id_token).to eq b_param.id_token
        expect(bike.creator).to eq b_param.creator
      end
      context "stolen" do
        # Even though status_with_owner passed - since it has stolen attrs
        let(:b_param_params) { {bike: {status: "status_with_owner"}, stolen_record: {phone: "7183839292"}} }
        it "is stolen" do
          expect(b_param).to be_valid
          expect(b_param.status).to eq "status_stolen"
          expect(b_param.stolen_attrs).to eq b_param_params[:stolen_record].as_json
          expect(bike.status).to eq "status_stolen"
          expect(bike.id).to be_blank
          expect(bike.b_param_id).to eq b_param.id
          expect(bike.b_param_id_token).to eq b_param.id_token
          expect(bike.creator).to eq b_param.creator
          stolen_record = bike.stolen_records.last
          expect(stolen_record).to be_present
          expect(stolen_record.phone).to eq b_param_params.dig(:stolen_record, :phone)
        end
      end
    end
    context "status overrides" do
      it "is stolen if it is stolen" do
        bike = described_class.build(BParam.new, status: "status_stolen")
        expect(bike.status).to eq "status_stolen"
      end
      it "impounded if status_impounded" do
        bike = described_class.build(BParam.new, status: "status_impounded")
        expect(bike.status).to eq "status_impounded"
      end
    end

    context "with address_record" do
      it "doesn't add an address_record by default" do
        expect(organization.additional_registration_fields.include?("reg_address")).to be_falsey
        expect(b_param.address_record_attributes).to be_blank
        expect(bike.address_record).to be_blank
      end

      context "with organization with reg_address" do
        let!(:organization) { FactoryBot.create(:organization_with_organization_features, :in_chicago, enabled_feature_slugs: ["reg_address"]) }
        let(:state_id) { organization.state_id }
        let(:target_attributes) do
          {id: nil, kind: "bike", city: "Chicago", region_record_id: state_id,
           country_id: Country.united_states_id, street: nil, postal_code: nil}
        end
        let(:b_param_params) { {bike: {creation_organization_id: organization.id}} }
        it "returns address with organization's country, region_string and city" do
          expect(organization.reload.city).to eq "Chicago"
          expect(organization.street).to be_present
          expect(organization.additional_registration_fields.include?("reg_address")).to be_truthy
          expect(b_param.address_record_attributes).to be_blank
          expect(described_class.include_address_record?(bike.creation_organization)).to be_truthy
          expect(bike.address_record).to match_hash_indifferently target_attributes
        end
        context "with b_param with address_record_attributes" do
          let(:b_param_params) do
            {
              bike: {
                creation_organization_id: organization.id,
                address_record_attributes: {
                  city: "San Francisco",
                  country_id: Country.united_states_id,
                  region_string: "CA",
                  street: "3333 nowhere",
                  postal_code: "94110"
                }
              }
            }
          end
          it "returns the b_param address_record_attributes" do
            expect(organization.reload.city).to eq "Chicago"
            expect(organization.street).to be_present
            expect(organization.additional_registration_fields.include?("reg_address")).to be_truthy
            expect(b_param.address_record_attributes).to be_present
            expect(described_class.include_address_record?(bike.creation_organization)).to be_truthy
            expect(bike.address_record).to match_hash_indifferently b_param_params[:bike][:address_record_attributes]
          end
        end

        context "with organization without a location" do
          # NOTE: This would be an error situation, just want to make sure things don't explode
          let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["reg_address"]) }
          it "returns an address_record" do
            expect(organization.reload.city).to be_blank
            expect(described_class.include_address_record?(bike.creation_organization)).to be_truthy
            expect(bike.address_record).to be_present
            expect(bike.address_record.attributes.compact).to match_hash_indifferently(kind: "bike")
          end
        end
      end
    end
  end

  describe "include_fields" do
    let(:organization) { Organization.new }
    let(:user_with_phone) { User.new(phone: "888.888.8888") }
    it "is falsey" do
      expect(described_class.include_address_record?).to be_falsey
      expect(described_class.include_address_record?(organization)).to be_falsey
      expect(described_class.include_address_record?(organization, User.new)).to be_falsey
      expect(described_class.include_address_record?(organization, user_with_phone)).to be_falsey
    end

    context "with enabled features" do
      let(:labels) { {reg_phone: "You have to put this in, jerk"}.as_json }
      let(:feature_slugs) { %w[reg_address reg_phone] }
      let!(:organization) { FactoryBot.create(:organization_with_organization_features, :in_chicago, enabled_feature_slugs: ["reg_address"]) }
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:user_with_registration_organization) { FactoryBot.create(:user_registration_organization, organization:).user }
      let(:user_with_address) { FactoryBot.create(:user_confirmed, :address_in_edmonton, address_set_manually: false) }
      let(:user_with_address_manually) { FactoryBot.create(:user_confirmed, :address_in_edmonton, address_set_manually: true) }
      it "includes" do
        expect(described_class.include_address_record?(organization)).to be_truthy
        expect(described_class.include_address_record?(organization, User.new)).to be_truthy
        expect(described_class.include_address_record?(organization, user_with_phone)).to be_truthy
        expect(user_with_registration_organization.reload.address_record?).to be_falsey
        expect(described_class.include_address_record?(organization, user_with_registration_organization)).to be_truthy

        expect(user_with_address.reload.address_set_manually).to be_falsey
        expect(described_class.include_address_record?(organization, user_with_address)).to be_truthy

        expect(user_with_address_manually.reload.address_set_manually).to be_truthy
        expect(described_class.include_address_record?(organization, user_with_address_manually)).to be_falsey
      end
    end
  end
end
