require "rails_helper"

RSpec.describe UpdateModelAuditJob, type: :job do
  let(:instance) { described_class.new }

  describe "enqueue_for?" do
    let(:model_audit) { FactoryBot.build(:model_audit, bikes_count: 0) }
    it "is false" do
      expect(described_class.locked_for?(model_audit.id)).to be_falsey
      expect(model_audit.bikes_count).to eq 0
      expect(model_audit.counted_matching_bikes_count).to eq 0
      expect(described_class.enqueue_for?(model_audit)).to be_falsey
    end
    context "bike not counted" do
      let!(:bike) { FactoryBot.create(:bike, manufacturer: model_audit.manufacturer, frame_model: model_audit.frame_model) }
      it "is truthy" do
        expect(described_class.enqueue_for?(model_audit)).to be_truthy
      end
    end
  end

  describe "should_delete_model_audit?" do
    let(:model_audit) { FactoryBot.create(:model_audit, bikes_count: 0) }
    let!(:bike) { FactoryBot.create(:bike, manufacturer: model_audit.manufacturer, frame_model: model_audit.frame_model, propulsion_type: propulsion_type) }
    let(:propulsion_type) { "throttle" }
    it "is false" do
      expect(model_audit.reload.counted_matching_bikes_count).to eq 1
      expect(model_audit.delete_if_no_bikes?).to be_truthy
      expect(described_class.delete_model_audit?(model_audit)).to be_falsey
    end
    context "0 bikes" do
      it "is truthy" do
        bike.destroy
        expect(model_audit.reload.counted_matching_bikes_count).to eq 0
        expect(described_class.delete_model_audit?(model_audit)).to be_truthy
      end
    end
    context "no motorized bikes" do
      let(:propulsion_type) { "hand-pedal" }
      it "is truthy" do
        expect(model_audit.reload.counted_matching_bikes_count).to eq 1
        expect(described_class.delete_model_audit?(model_audit)).to be_truthy
      end
      context "manufacturer motorized_only" do
        it "is falsey" do
          model_audit.manufacturer.update(motorized_only: true)
          expect(model_audit.reload.counted_matching_bikes_count).to eq 1
          expect(described_class.delete_model_audit?(model_audit)).to be_falsey
        end
      end
    end
    context "unknown_model" do
      let(:model_audit) { FactoryBot.create(:model_audit, frame_model: "ecargo black women's tricycle") }
      it "returns true" do
        expect(model_audit.reload.counted_matching_bikes_count).to eq 0
        bike.update_attribute :model_audit_id, model_audit.id
        expect(model_audit.unknown_model?).to be_falsey
        expect(model_audit.reload.counted_matching_bikes_count).to eq 0
        expect(model_audit.delete_if_no_bikes?).to be_truthy
        expect(model_audit.should_be_unknown_model?).to be_truthy
        expect(described_class.delete_model_audit?(model_audit)).to be_truthy
      end
    end
  end

  describe "perform" do
    let!(:bike1) { FactoryBot.create(:bike, propulsion_type: "pedal-assist-and-throttle", frame_model: frame_model1, manufacturer: manufacturer) }
    let(:frame_model1) { "Party model" }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:bike2) { FactoryBot.create(:bike, manufacturer: manufacturer, frame_model: frame_model2, cycle_type: :cargo, model_audit_id: model_audit&.id, updated_at: 10.minutes.ago) }
    let(:frame_model2) { "Party MODEL " }
    let!(:model_audit) { FactoryBot.create(:model_audit, frame_model: bike1.frame_model, manufacturer: manufacturer) }
    context "skipped env" do
      it "noops" do
        stub_const("UpdateModelAuditJob::SKIP_PROCESSING", true)
        expect(ModelAudit.count).to eq 1
        Sidekiq::Job.clear_all
        expect(described_class.locked_for?(model_audit.id)).to be_falsey
        expect {
          instance.perform(model_audit.id)
        }.to change(ModelAudit, :count).by 0
        expect(described_class.jobs.count).to eq 0
      end
    end
    context "redlock" do
      before do
        @lock_manager = described_class.new_lock_manager
        @redlock = @lock_manager.lock(described_class.redlock_key(model_audit.id), 5000)
      end
      after { @lock_manager.unlock(@redlock) }
      it "noops" do
        expect(ModelAudit.count).to eq 1
        Sidekiq::Job.clear_all
        expect(described_class.locked_for?(model_audit.id)).to be_truthy
        expect {
          instance.perform(model_audit.id)
        }.to change(ModelAudit, :count).by 0
        expect(described_class.jobs.count).to eq 0
        expect(bike2.reload.updated_at).to be < 9.minutes.ago
      end
    end
    context "should_be_unknown_model?" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Party Model Bikes") }
      it "deletes model and re-enqueues" do
        expect(bike2.reload.model_audit_id).to eq model_audit.id
        expect(model_audit.reload.should_be_unknown_model?).to be_truthy
        expect(model_audit.unknown_model?).to be_falsey
        expect(ModelAudit.count).to eq 1
        Sidekiq::Job.clear_all
        expect(described_class.locked_for?(model_audit.id)).to be_falsey
        expect {
          instance.perform(model_audit.id)
        }.to change(ModelAudit, :count).by(-1)
        expect(FindOrCreateModelAuditJob.jobs.count).to eq 1

        expect { FindOrCreateModelAuditJob.drain }.to change(ModelAudit, :count).by 1
        new_model_audit = ModelAudit.last
        expect(new_model_audit.should_be_unknown_model?).to be_falsey
        expect(new_model_audit.unknown_model?).to be_truthy
        expect(bike2.reload.model_audit_id).to eq new_model_audit.id
      end
    end
    context "bike_organized organization" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:time) { 1.day.ago }
      let!(:bike3) { FactoryBot.create(:bike_organized, created_at: time, creation_organization: organization, frame_model: "PARTY  model", manufacturer: manufacturer, propulsion_type: "throttle") }
      before { expect(bike2).to be_present }
      # factory organization_with_organization_features enqueues inline sidekiq processing, which runs this job. So handle it manually
      before { organization.update_attribute(:enabled_feature_slugs, ["model_audits"]) }
      it "creates an organization_model_audit" do
        expect(OrganizationModelAudit.count).to eq 0
        expect(OrganizationModelAudit.organizations_to_audit.pluck(:id)).to eq([organization.id])
        expect(organization.reload.bikes.pluck(:id)).to eq([bike3.id])
        expect(model_audit.reload.matching_bikes.pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
        expect(bike3.frame_model.downcase).to eq bike1.frame_model.downcase # check normalization
        Sidekiq::Job.clear_all
        expect {
          instance.perform(model_audit.id)
        }.to change(ModelAudit, :count).by 0
        expect(Bike.unscoped.where(model_audit_id: model_audit.id).count).to eq 3
        # bike2 shouldn't have been updated
        expect(bike2.reload.updated_at).to be < 9.minutes.ago
        expect(bike1.reload.model_audit_id).to eq model_audit.id
        expect(model_audit.organization_model_audits.count).to eq 1
        organization_model_audit = model_audit.organization_model_audits.first
        expect(organization_model_audit.organization_id).to eq organization.id
        expect(organization_model_audit.bikes_count).to eq 1
        expect(organization_model_audit.certification_status).to be_nil
        expect(organization_model_audit.last_bike_created_at).to be_within(1).of time
      end
      context "likely_spam bike" do
        it "creates an organization_model_audit, updates likely_spam" do
          expect(organization.reload.bikes.pluck(:id)).to eq([bike3.id])
          bike2.update(propulsion_type: "throttle")
          bike3.update(likely_spam: true)
          expect(Bike.count).to eq 2
          expect(Bike.unscoped.count).to eq 3
          expect {
            instance.perform(model_audit.id)
          }.to change(ModelAudit, :count).by 0
          expect(Bike.unscoped.where.not(model_audit_id: nil).count).to eq 3
          expect(bike2.reload.model_audit_id).to eq model_audit.id
          expect(bike3.reload.model_audit_id).to eq model_audit.id
          expect(model_audit.organization_model_audits.count).to eq 1
          organization_model_audit = model_audit.organization_model_audits.first
          expect(organization_model_audit.organization_id).to eq organization.id
          expect(organization_model_audit.bikes_count).to eq 0
          expect(organization_model_audit.certification_status).to be_nil
          expect(organization_model_audit.last_bike_created_at).to be_nil
          # frame_model update, with a frame_model still in model_audit
          expect(model_audit.delete_if_no_bikes?).to be_truthy
          bike1.update(frame_model: "Unknown")
          expect(model_audit.matching_bike?(bike1)).to be_falsey
          expect(model_audit.reload.matching_bikes.pluck(:id)).to match_array([bike2.id, bike3.id])
          FindOrCreateModelAuditJob.new.perform(bike1.id)
          # instance.perform(model_audit.id) # passing bike_id that still matches
          expect(described_class.jobs.count).to eq 2
          described_class.drain # Has to run a second time
          expect(ModelAudit.count).to eq 2
          model_audit_unknown = ModelAudit.order(:id).last
          expect(model_audit_unknown.bikes_count).to eq 1
          expect(model_audit_unknown.matching_bike?(bike1)).to be_truthy
          expect(model_audit_unknown.frame_model).to be_nil
          expect(bike1.reload.model_audit_id).to eq model_audit_unknown.id
          expect(bike2.reload.model_audit_id).to eq model_audit.id
          expect(bike3.reload.model_audit_id).to eq model_audit.id
          expect(OrganizationModelAudit.count).to eq 2
          organization_model_audit_unknown = OrganizationModelAudit.order(:id).last
          expect(organization_model_audit_unknown.bikes_count).to eq 0
          # frame_model update, with only likely_spam frame_model in model_audit - deletes the model audit
          expect(model_audit.matching_bike?(bike2)).to be_truthy
          bike2.update(frame_model: "IDK")
          FindOrCreateModelAuditJob.new.perform(bike2.id)
          expect(model_audit.matching_bike?(bike2)).to be_falsey
          instance.perform(model_audit.id) # passing already updated bike_id
          expect(described_class.jobs.map { |j| j["args"] }.flatten).to match_array([model_audit.id, model_audit_unknown.id])
          described_class.drain
          expect(ModelAudit.where(id: model_audit.id).count).to eq 0
          expect(bike1.reload.model_audit_id).to eq model_audit_unknown.id
          expect(bike2.reload.model_audit_id).to eq model_audit_unknown.id
          expect(bike3.reload.model_audit_id).to be_nil
          expect(OrganizationModelAudit.count).to eq 1
          expect(OrganizationModelAudit.where(id: organization_model_audit.id).count).to eq 0
          expect(organization_model_audit_unknown.reload.bikes_count).to eq 0
        end
      end
      context "user_hidden and model_attestation" do
        # let(:model_audit) { FactoryBot.create(:model_audit, frame_model: "Party Model", manufacturer: manufacturer, bikes_count: 3) }
        let!(:model_attestation) { FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certification_proof_url) }
        it "updates" do
          expect(organization.reload.bikes.pluck(:id)).to eq([bike3.id])
          bike3.update(user_hidden: true)
          expect(model_audit.reload.matching_bikes.pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
          Sidekiq::Job.clear_all
          expect {
            instance.perform(model_audit.id)
          }.to change(ModelAudit, :count).by 0
          expect(model_audit.reload.bikes_count).to eq 3
          expect(model_audit.certification_status).to be_nil

          expect(Bike.unscoped.where.not(model_audit_id: nil).count).to eq 3
          expect(bike1.reload.model_audit_id).to eq model_audit.id
          expect(bike2.reload.model_audit_id).to eq model_audit.id
          expect(bike3.reload.model_audit_id).to eq model_audit.id
          expect(model_audit.organization_model_audits.count).to eq 1
          organization_model_audit = model_audit.organization_model_audits.first
          expect(organization_model_audit.organization_id).to eq organization.id

          expect(organization_model_audit.bikes_count).to eq 0 # TODO: better handling of user_hidden org bikes
          expect(organization_model_audit.certification_status).to be_nil
          expect(organization_model_audit.last_bike_created_at).to be_nil
        end
      end
    end
    describe "duplicate model_audit" do
      let(:model_audit2) { FactoryBot.create(:model_audit, frame_model: "Party Model", manufacturer: Manufacturer.other, manufacturer_other: model_audit.manufacturer.name.to_s) }
      it "deletes" do
        expect(bike2.model_audit_id).to be_present
        # It matches, because a matching bike has a model_audit
        bike1.update(model_audit_id: model_audit2.id)
        expect(described_class.enqueue_for?(model_audit)).to be_truthy
        model_attestation = FactoryBot.create(:model_attestation, model_audit: model_audit2)
        Sidekiq::Job.clear_all
        expect {
          instance.perform(model_audit2.id)
        }.to change(ModelAudit, :count).by(-1)

        expect(bike1.reload.model_audit_id).to eq model_audit.id
        expect(bike2.reload.model_audit_id).to eq model_audit.id
        expect(ModelAudit.pluck(:id)).to eq([model_audit.id])
        expect(model_attestation.reload.model_audit_id).to eq model_audit.id
      end
    end
    describe "model_audit no counted bikes" do
      before { bike1.update(model_audit: model_audit, likely_spam: true) }
      it "deletes" do
        FactoryBot.create(:organization_model_audit, model_audit: model_audit)
        expect(model_audit.reload.bikes.count).to eq 0 # Because likely_spam
        expect(model_audit.counted_matching_bikes_count).to eq 0
        expect(described_class.enqueue_for?(model_audit)).to be_truthy
        expect {
          instance.perform(model_audit.id)
        }.to change(ModelAudit, :count).by(-1)
        expect(bike1.reload.model_audit_id).to be_nil
        expect(OrganizationModelAudit.count).to eq 0
      end
      context "with model_attestation" do
        it "doesn't delete" do
          expect(model_audit.reload.bikes.count).to eq 0 # Because likely_spam
          expect(model_audit.counted_matching_bikes_count).to eq 0
          Sidekiq::Job.clear_all
          # Creating a model attestation enqueues job
          FactoryBot.create(:model_attestation, model_audit: model_audit, kind: "certified_by_manufacturer")
          expect(described_class.jobs.count).to eq 1
          expect {
            instance.perform(model_audit.id)
          }.to change(ModelAudit, :count).by 0
          expect(bike1.reload.model_audit_id).to eq model_audit.id

          expect(model_audit.reload.certification_status).to eq "certified_by_manufacturer"
          expect(model_audit.reload.bikes_count).to eq 0
          expect(model_audit.counted_matching_bikes_count).to eq 0
          expect(described_class.enqueue_for?(model_audit)).to be_falsey
        end
      end
    end

    context "manufacturer_other" do
      let(:manufacturer) { Manufacturer.other }
      let!(:bike3) { FactoryBot.create(:bike, propulsion_type: "pedal-assist-and-throttle", frame_model: frame_model1, manufacturer: Manufacturer.other, manufacturer_other: "SALSA BIKES") }
      let(:mnfg_salsa) { FactoryBot.create(:manufacturer, name: "Salsa Bikes") }
      before do
        bike2.update(manufacturer: Manufacturer.other, manufacturer_other: "Salsa bicycles", model_audit_id: model_audit.id)
        model_audit.update(manufacturer: Manufacturer.other, manufacturer_other: "Salsa")
        bike1.update(manufacturer: mnfg_salsa)
      end
      # Separate test for fix_manufacturer! - it's what handles the majority of the logic
      it "fix_manufacturer! fixes" do
        expect(bike1.reload.model_audit_id).to be_blank
        expect(bike2.reload.mnfg_name).to eq "Salsa bicycles"

        expect(model_audit.reload.mnfg_name).to eq "Salsa"
        expect(model_audit.bikes.pluck(:id)).to eq([bike2.id])
        expect(model_audit.matching_bikes.pluck(:id)).to match_array([])

        instance.send(:fix_manufacturer!, model_audit)

        expect(model_audit.reload.manufacturer_id).to eq mnfg_salsa.id
        expect(model_audit.bikes.pluck(:id)).to eq([bike2.id])
        expect(model_audit.matching_bikes.pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
      end
      it "updates" do
        expect(bike1.reload.model_audit_id).to be_blank
        expect {
          # expect(instance.send(:should_delete_model_audit?, model_audit)).to be_falsey
          instance.perform(model_audit.id)
        }.to change(ModelAudit, :count).by 0
        expect(model_audit.reload.manufacturer_id).to eq mnfg_salsa.id
        expect(model_audit.manufacturer_other).to be_nil
        expect(model_audit.organization_model_audits.count).to eq 0
        expect(model_audit.bikes.count).to eq 3

        expect(bike2.reload.model_audit_id).to eq model_audit.id
        expect(bike2.manufacturer_id).to eq mnfg_salsa.id
        expect(bike2.frame_model.downcase).to eq bike1.reload.frame_model.downcase
        expect(bike3.reload.model_audit_id).to eq model_audit.id
      end
    end
  end
end
