require "rails_helper"

RSpec.describe FindOrCreateModelAuditWorker, type: :job do
  let(:instance) { described_class.new }

  describe "enqueue_for?" do
    let(:bike) { FactoryBot.build(:bike) }
    it "is false" do
      expect(described_class.enqueue_for?(bike)).to be_falsey
    end
    shared_examples_for :non_default_scoped_bikes do
      context "example" do
        before { bike.example = true }
        it "is falsey" do
          expect(described_class.enqueue_for?(bike)).to be_falsey
        end
      end
      context "deleted" do
        before { bike.deleted_at = Time.current - 1 }
        it "is falsey" do
          expect(described_class.enqueue_for?(bike)).to be_falsey
        end
      end
      context "likely_spam" do
        before { bike.likely_spam = true }
        it "is falsey" do
          expect(described_class.enqueue_for?(bike)).to be_falsey
        end
      end
      context "user_hidden" do
        before { bike.user_hidden = true }
        it "is truthy" do
          expect(described_class.enqueue_for?(bike)).to be_truthy
        end
      end
    end
    context "motorized" do
      let(:bike) { Bike.new(propulsion_type: "throttle", cycle_type: "bike", frame_model: "Something") }
      it "is truthy" do
        expect(described_class.enqueue_for?(bike)).to be_truthy
      end

      include_examples :non_default_scoped_bikes
    end
    context "bike with model_audit id" do
      let(:bike) { FactoryBot.build(:bike, model_audit_id: 33) }
      it "is true" do
        expect(described_class.enqueue_for?(bike)).to be_truthy
      end

      include_examples :non_default_scoped_bikes
    end
  end

  describe "perform" do
    let!(:bike1) { FactoryBot.create(:bike, propulsion_type: "pedal-assist-and-throttle", frame_model: frame_model1) }
    let(:frame_model1) { "Party model" }
    let(:manufacturer) { bike1.manufacturer }
    let(:bike2) { FactoryBot.create(:bike, manufacturer: manufacturer, frame_model: frame_model2, cycle_type: :cargo, model_audit_id: model_audit&.id) }
    let(:frame_model2) { "Party MODEL " }
    let(:model_audit) { nil }
    let(:basic_target_attributes) do
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
        instance.perform(bike1.id)
      }.to change(ModelAudit, :count).by 1
      new_model_audit = bike1.reload.model_audit
      expect(bike2.reload.model_audit_id).to be_blank # This worker doesn't update other bikes
      expect_attrs_to_match_hash(new_model_audit, basic_target_attributes)
      expect(new_model_audit.organization_model_audits.count).to eq 0
    end
    context "likely_spam and example" do
      it "does not create a model_audit" do
        bike1.update(example: true)
        expect(described_class.enqueue_for?(bike1)).to be_falsey
        bike2.update(likely_spam: true)
        expect(described_class.enqueue_for?(bike2)).to be_falsey
        expect {
          expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
          instance.perform(bike1.id)
        }.to change(ModelAudit, :count).by 0
      end
    end
    context "user_hidden and deleted" do
      it "creates a model_audit for user_hidden" do
        bike1.update(user_hidden: true)
        expect(described_class.enqueue_for?(bike1)).to be_truthy
        bike2.destroy
        expect(described_class.enqueue_for?(bike2)).to be_falsey
        expect {
          expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
          instance.perform(bike1.id)
        }.to change(ModelAudit, :count).by 1
        new_model_audit = bike1.reload.model_audit
        expect(bike2.reload.model_audit_id).to be_blank # This worker doesn't update other bikes
        expect_attrs_to_match_hash(new_model_audit, basic_target_attributes)
      end
    end
  end
end
