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
      Sidekiq::Worker.clear_all
      expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
      expect {
        instance.perform(bike1.id)
      }.to change(ModelAudit, :count).by 1
      new_model_audit = bike1.reload.model_audit
      expect(bike2.reload.model_audit_id).to be_blank # This worker doesn't update other bikes
      expect(new_model_audit).to match_hash_indifferently basic_target_attributes
      # Organization model audits are created by UpdateModelAuditWorker
      expect(new_model_audit.organization_model_audits.count).to eq 0
      expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to eq([new_model_audit.id])
    end
    context "unknown frame_model" do
      let(:frame_model1) { "idk" }
      let(:frame_model2) { "unknown" }
      it "creates a model_audit" do
        expect(bike1.model_audit_id).to be_blank
        expect(bike2.model_audit_id).to be_blank
        Sidekiq::Worker.clear_all
        expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id])
        expect {
          instance.perform(bike1.id)
        }.to change(ModelAudit, :count).by 1
        new_model_audit = bike1.reload.model_audit
        expect(bike2.reload.model_audit_id).to be_blank # This worker doesn't update other bikes
        expect(new_model_audit).to match_hash_indifferently basic_target_attributes.merge(frame_model: nil, cycle_type: :bike)
        # Organization model audits are created by UpdateModelAuditWorker
        expect(new_model_audit.organization_model_audits.count).to eq 0
        expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to eq([new_model_audit.id])
      end
      context "bike2 is motorized" do
        before { bike2.update(propulsion_type: "pedal-assist") }
        it "matches" do
          Sidekiq::Worker.clear_all
          expect {
            expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
            instance.perform(bike1.id)
          }.to change(ModelAudit, :count).by 1
          new_model_audit = bike1.reload.model_audit
          expect(bike2.reload.model_audit_id).to be_blank # This worker doesn't update other bikes
          # NOTE: this uses the cycle_type of bike2
          expect(new_model_audit).to match_hash_indifferently basic_target_attributes.merge(frame_model: nil, propulsion_type: "pedal-assist")
          expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to eq([new_model_audit.id])
        end
        context "frame model is a model_bare_vehicle_type" do
          let(:frame_model1) { "ladies BIKE" }
          let(:frame_model2) { "medium Men's folding utility bicycle" }
          it "creates a model_audit" do
            expect(ModelAudit.unknown_model?(bike1.frame_model, manufacturer_id: bike1.manufacturer_id)).to be_truthy
            expect(ModelAudit.unknown_model?(bike2.frame_model, manufacturer_id: bike2.manufacturer_id)).to be_truthy
            Sidekiq::Worker.clear_all
            expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to eq([bike1.id])
            expect(ModelAudit.matching_bikes_for(bike2).pluck(:id)).to eq([bike2.id])
            expect { instance.perform(bike1.id) }.to change(ModelAudit, :count).by 1
            new_model_audit = bike1.reload.model_audit
            expect(bike2.reload.model_audit_id).to be_blank # This worker doesn't update other bikes
            expect(new_model_audit).to match_hash_indifferently basic_target_attributes.merge(frame_model: nil, cycle_type: "bike")
            # Organization model audits are created by UpdateModelAuditWorker
            expect(new_model_audit.organization_model_audits.count).to eq 0
            expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to eq([new_model_audit.id])
            # Should bikes with unknown models, which are marked e-vehicle be grouped together with non-e-vehicles?
            # Currently they do, which seems likely to get false positives
            # THIS IS A PROBLEM. Someone marks a rockhopper as an e-vehicle, and then all orgs have all their rockhopper in model audits
            expect { instance.perform(bike2.id) }.to change(ModelAudit, :count).by 0
            expect(bike2.reload.model_audit_id).to eq new_model_audit.id
          end
        end
      end
    end
    context "matching model_audit exists" do
      let(:model_audit) { FactoryBot.create(:model_audit, manufacturer: manufacturer, frame_model: frame_model1) }
      def expect_assigned_to_model_audit
        expect(bike2.model_audit_id).to eq model_audit.id
        expect(model_audit.reload.matching_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
        Sidekiq::Worker.clear_all
        expect {
          instance.perform(bike1.id)
        }.to change(ModelAudit, :count).by 0
        expect(bike1.reload.model_audit_id).to eq model_audit.id
        expect(bike2.reload.model_audit_id).to eq model_audit.id
      end
      it "assigns bike to model_audit" do
        expect_assigned_to_model_audit

        expect(model_audit.matching_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(UpdateModelAuditWorker.enqueue_for?(model_audit)).to be_truthy
        expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to eq([model_audit.id])
      end
      context "UpdateModelAuditWorker.enqueue_for? false" do
        before { allow(UpdateModelAuditWorker).to receive(:enqueue_for?) { false } }
        it "assigns bike, doesn't enqueue" do
          expect_assigned_to_model_audit

          expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to eq([])
        end
      end
      context "manufacturer other" do
        let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Segway Ninebot (Ninebot)", motorized_only: true) }
        let!(:bike1) { FactoryBot.create(:bike, frame_model: "iDK", manufacturer: Manufacturer.other, manufacturer_other: "Ninebot") }
        let(:frame_model1) { nil }
        let(:frame_model2) { "Unknown" }
        it "assigns the model_audit" do
          expect(bike2.model_audit_id).to eq model_audit.id
          Sidekiq::Worker.clear_all
          # This adds some extra calculations, but I think it's worth it
          expect(described_class.enqueue_for?(bike1)).to be_truthy
          expect {
            instance.perform(bike1.id)
          }.to change(ModelAudit, :count).by 0
          expect(bike1.reload.model_audit_id).to eq model_audit.id
          expect(bike1.manufacturer_id).to eq manufacturer.id
          # expect that the matching is corrected!
          expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
        end
      end
    end
    context "not matching model_audit" do
      let(:model_audit) { FactoryBot.create(:model_audit) }
      # This test replicates what would happen if a user updated a bike and it no longer matched the vehicle
      it "enqueues update for model, creates new_model_audit" do
        Sidekiq::Worker.clear_all
        expect(bike2.model_audit_id).to eq model_audit.id
        expect(model_audit.reload.matching_bikes.pluck(:id)).to eq([])
        expect {
          # NOTE: Enqueues bike2
          instance.perform(bike2.id)
        }.to change(ModelAudit, :count).by 1
        expect(bike1.reload.model_audit_id).to be_blank
        expect(bike2.reload.model_audit_id).to_not be_blank

        new_model_audit = bike2.reload.model_audit
        expect(new_model_audit.id).to_not eq model_audit.id
        expect(new_model_audit).to match_hash_indifferently basic_target_attributes.merge(frame_model: "Party MODEL")
        expect(new_model_audit.organization_model_audits.count).to eq 0
        expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to match_array([model_audit.id, new_model_audit.id])
      end
    end
    context "deleted model_audit" do
      it "updates" do
        bike1.update(model_audit_id: 12)
        Sidekiq::Worker.clear_all
        expect {
          instance.perform(bike1.id)
        }.to change(ModelAudit, :count).by 1
        new_model_audit = bike1.reload.model_audit
        expect(new_model_audit).to match_hash_indifferently basic_target_attributes.merge(cycle_type: "bike")
        expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to match_array([12, new_model_audit.id])
      end
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
        expect(UpdateModelAuditWorker.jobs.count).to eq 0
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
        expect(new_model_audit).to match_hash_indifferently basic_target_attributes
        expect(UpdateModelAuditWorker.jobs.map { |j| j["args"] }.flatten).to eq([new_model_audit.id])
      end
    end
  end
end
