require "rails_helper"

RSpec.describe UpdateModelAuditWorker, type: :job do
  let(:subject) { described_class.new }

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
    let(:bike) { FactoryBot.create(:bike, propulsion_type: "pedal-assist-and-throttle", frame_model: "Party model", model_audit_id: model_audit&.id) }
    let!(:bike2) { FactoryBot.create(:bike_organized, manufacturer: bike.manufacturer, frame_model: "Party MODEL ", cycle_type: :cargo, model_audit_id: model_audit&.id) }
    let(:model_audit) { nil }
    let(:organization) { bike2.organization }
    let(:bike_attributes) do
      {
        propulsion_type: "pedal-assist-and-throttle",
        cycle_type: :cargo,
        certification_status: nil,
        manufacturer_id: bike.manufacturer_id,
        frame_model: "Party model",
        manufacturer_other: nil
      }
    end
    it "creates a model_audit" do
      expect(bike.model_audit_id).to be_blank
      expect {
        instance.perform(nil, bike.id)
      }.to change(ModelAudit, :count).by 1
      new_model_audit = bike.reload.model_audit
      expect(bike2.reload.model_audit_id).to eq new_model_audit.id
      expect_attrs_to_match_hash(new_model_audit, bike_attributes)
      expect(new_model_audit.organization_model_audit.count).to eq 1
      organization_model_audit = new_model_audit.organization_model_audit.first
      expect(organization_model_audit.organization_id).to eq organization.id
      expect(organization_model_audit.bikes_count).to eq 1
      expect(organization_model_audit.certification_status).to be_nil
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
  end
end
