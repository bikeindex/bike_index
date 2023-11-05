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
    let(:bike1) { FactoryBot.create(:bike, propulsion_type: "pedal-assist-and-throttle", frame_model: "Party model") }
    let(:manufacturer) { bike1.manufacturer }
    let!(:bike2) { FactoryBot.create(:bike, manufacturer: manufacturer, frame_model: "Party MODEL ", cycle_type: :cargo, model_audit_id: model_audit&.id) }
    let(:model_audit) { nil }
    let(:organization)
    let(:target_attributes) do
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
      expect {
        expect(instance.matching_bikes_for_bike(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
        instance.perform(nil, bike1.id)
      }.to change(ModelAudit, :count).by 1
      new_model_audit = bike1.reload.model_audit
      expect(bike2.reload.model_audit_id).to eq new_model_audit.id
      expect_attrs_to_match_hash(new_model_audit, target_attributes)
      expect(new_model_audit.organization_model_audit.count).to eq 1
      organization_model_audit = new_model_audit.organization_model_audit.first
      expect(organization_model_audit.organization_id).to eq organization.id
      expect(organization_model_audit.bikes_count).to eq 1
      expect(organization_model_audit.certification_status).to be_nil
    end
    context "bike_organized organization" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["model_audits"]) }
      let!(:bike3) { FactoryBot.create(:bike_organized, organization: organization, frame_model: "PARTY model", manufacturer: manufacturer) }
      it "creates an organization_model_audit"
    end
    context "existing model_audit" do
      it "updates" do
        # Updates the *bike* cycle_type and propulsion_type,
        # it doesn't reassign bike2
      end
      context "existing model_audit manufacturer_other" do
      end
    end
    context "model_attestations" do
    end
    context "matching but manufacturer_other" do
    end
  end
end
