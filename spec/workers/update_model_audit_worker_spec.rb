require "rails_helper"

RSpec.describe UpdateModelAuditWorker, type: :job do
  let(:instance) { described_class.new }

  describe "enqueue_for?" do
    let(:bike) { FactoryBot.build(:bike) }
    it "is false" do
      expect(described_class.enqueue_for?(bike)).to be_falsey
    end
    context "e-bike" do
      let(:bike) { Bike.new(propulsion_type: "throttle", cycle_type: "bike", frame_model: "Something") }
      it "is truthy" do
        expect(described_class.enqueue_for?(bike)).to be_truthy
      end
    end
  end

  describe "perform" do
    let!(:bike1) { FactoryBot.create(:bike, propulsion_type: "pedal-assist-and-throttle", frame_model: frame_model1) }
    let(:frame_model1) { "Party model" }
    let(:manufacturer) { bike1.manufacturer }
    let(:bike2) { FactoryBot.create(:bike, manufacturer: manufacturer, frame_model: frame_model2, cycle_type: :cargo, model_audit_id: model_audit&.id) }
    let(:frame_model2) { "Party MODEL " }
    let(:model_audit) { nil }
    let(:basid_target_attributes) do
      {
        propulsion_type: "pedal-assist-and-throttle",
        cycle_type: :cargo,
        certification_status: nil,
        manufacturer_id: manufacturer.id,
        frame_model: "Party model",
        manufacturer_other: nil
      }
    end
    it "creates a model_audit" do
      expect(bike1.model_audit_id).to be_blank
      expect(bike2.model_audit_id).to be_blank
      expect {
        expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
        instance.perform(nil, bike1.id)
      }.to change(ModelAudit, :count).by 1
      new_model_audit = bike1.reload.model_audit
      expect(bike2.reload.model_audit_id).to eq new_model_audit.id
      expect_attrs_to_match_hash(new_model_audit, basid_target_attributes)
      expect(new_model_audit.organization_model_audits.count).to eq 0
    end
    context "bike_organized organization" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["model_audits"]) }
      let(:time) { Time.current - 1.day }
      let!(:bike3) { FactoryBot.create(:bike_organized, created_at: time, creation_organization: organization, frame_model: "PARTY  model", manufacturer: manufacturer) }
      it "creates an organization_model_audit" do
        expect(organization.reload.bikes.pluck(:id)).to eq([bike3.id])
        bike2.update(likely_spam: true)
        expect(Bike.count).to eq 2
        expect(Bike.unscoped.count).to eq 3
        expect(bike3.frame_model.downcase).to eq bike3.frame_model.downcase
        expect {
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 1
        expect(Bike.unscoped.where.not(model_audit_id: nil).count).to eq 3
        new_model_audit = bike1.reload.model_audit
        expect(bike2.reload.model_audit_id).to eq new_model_audit.id
        expect_attrs_to_match_hash(new_model_audit, basid_target_attributes)
        expect(new_model_audit.organization_model_audits.count).to eq 1
        organization_model_audit = new_model_audit.organization_model_audits.first
        expect(organization_model_audit.organization_id).to eq organization.id
        expect(organization_model_audit.bikes_count).to eq 1
        expect(organization_model_audit.certification_status).to be_nil
        expect(organization_model_audit.last_bike_created_at).to be_within(1).of time
      end
      # context "bike frame_model changes" do
      #   it "updates and deletes"
      # end
    end
    context "existing model_audit" do
      let(:model_audit) do
        FactoryBot.create(:model_audit,
          frame_model: "PARTY MODEL",
          manufacturer: manufacturer,
          cycle_type: "penny-farthing",
          propulsion_type: "throttle")
      end
      it "updates" do
        expect(bike2.model_audit_id).to be_present
        # It matches, because a matching bike has a model_audit
        bike1.update(propulsion_type: "foot-pedal")
        expect(described_class.enqueue_for?(bike1)).to be_truthy
        # Updates the *passed bike* cycle_type and propulsion_type
        expect {
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 0
        expect(bike1.reload.model_audit_id).to eq model_audit.id
        expect(bike1.cycle_type).to eq "penny-farthing"
        expect(bike1.propulsion_type).to eq "throttle"
        # it doesn't update bike2
        expect(bike2.reload.cycle_type).to eq "cargo"
        expect(bike2.propulsion_type).to eq "foot-pedal"
        expect(bike2.model_audit_id).to eq model_audit.id
        expect(model_audit.reload.certification_status).to be_nil
        # Creating a model attestation enqueues the update
        expect(described_class.jobs.count).to eq(0)
        FactoryBot.create(:model_attestation, model_audit: model_audit, kind: "certified_by_manufacturer")
        expect(described_class.jobs.count).to eq 1
        described_class.drain
        expect(model_audit.reload.certification_status).to eq "certified_by_manufacturer"
      end
    end
    context "manufacturer_other" do
      let!(:bike3) { FactoryBot.create(:bike, propulsion_type: "pedal-assist-and-throttle", frame_model: frame_model1, manufacturer: Manufacturer.other, manufacturer_other: "SALSA BIKES") }
      before do
        bike1.update(manufacturer: Manufacturer.other, manufacturer_other: "Salsa bikes")
        bike2.update(manufacturer: Manufacturer.other, manufacturer_other: "Salsa")
      end
      it "updates" do
        expect(bike1.model_audit_id).to be_blank
        expect(bike1.mnfg_name).to eq "Salsa bikes"
        expect(bike2.mnfg_name).to eq "Salsa"
        expect {
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 1
        new_model_audit = bike1.reload.model_audit
        expect(bike2.reload.model_audit_id).to be_blank
        expect(bike2.manufacturer_id).to eq Manufacturer.other.id
        expect(bike2.frame_model.downcase).to eq bike1.reload.frame_model.downcase
        expect(bike3.reload.model_audit_id).to eq new_model_audit.id
        expect(new_model_audit.manufacturer_other).to eq "Salsa bikes"
        expect(new_model_audit.organization_model_audits.count).to eq 0
        # After updating to a known manufacturer, all the bikes update
        bike1.update(manufacturer_id: FactoryBot.create(:manufacturer, name: "Salsa").id)
        instance.perform(new_model_audit.id)
        expect(new_model_audit.reload.manufacturer_id).to eq bike1.manufacturer_id
        expect(new_model_audit.manufacturer_other).to be_nil
        expect(bike1.reload.model_audit_id).to eq new_model_audit.id

        expect(bike2.reload.model_audit_id).to eq new_model_audit.id
        expect(bike2.manufacturer_id).to eq new_model_audit.manufacturer_id

        expect(bike3.reload.model_audit_id).to eq new_model_audit.id
        expect(bike3.manufacturer_id).to eq new_model_audit.manufacturer_id
      end
    end

    context "model_unknown?" do
      let(:frame_model1) { "unkown" }
      let(:frame_model2) { nil }
      let(:target_attributes) { basic_target_attributes.merge(frame_model: nil) }
      it "creates with nil" do
        expect(bike1.model_audit_id).to be_blank
        expect {
          expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 1
        new_model_audit = bike1.reload.model_audit
        expect(bike2.reload.model_audit_id).to eq new_model_audit.id
        expect_attrs_to_match_hash(new_model_audit, target_attributes)
        expect(new_model_audit.organization_model_audits.count).to eq 0
      end
    end
  end
end
