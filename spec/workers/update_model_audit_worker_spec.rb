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
        instance.perform(nil, bike1.id)
      }.to change(ModelAudit, :count).by 1
      new_model_audit = bike1.reload.model_audit
      expect(bike2.reload.model_audit_id).to eq new_model_audit.id
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
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 0
      end
    end
    context "user_hidden and deleted" do
      it "creates a model_audit" do
        bike1.update(user_hidden: true)
        expect(described_class.enqueue_for?(bike1)).to be_truthy
        bike2.destroy
        expect(described_class.enqueue_for?(bike2)).to be_falsey
        expect {
          expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id])
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 1
        new_model_audit = bike1.reload.model_audit
        expect(bike2.reload.model_audit_id).to eq new_model_audit.id
        expect_attrs_to_match_hash(new_model_audit, basic_target_attributes)
      end
    end
    context "bike_organized organization" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["model_audits"]) }
      let(:time) { Time.current - 1.day }
      let!(:bike3) { FactoryBot.create(:bike_organized, created_at: time, creation_organization: organization, frame_model: "PARTY  model", manufacturer: manufacturer) }
      before { expect(bike2).to be_present }
      it "creates an organization_model_audit" do
        expect(organization.reload.bikes.pluck(:id)).to eq([bike3.id])
        expect(Bike.count).to eq 3
        expect(bike3.frame_model.downcase).to eq bike1.frame_model.downcase # check normalization
        expect {
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 1
        expect(Bike.unscoped.where.not(model_audit_id: nil).count).to eq 3
        new_model_audit = bike1.reload.model_audit
        expect(bike2.reload.model_audit_id).to eq new_model_audit.id
        expect_attrs_to_match_hash(new_model_audit, basic_target_attributes)
        expect(new_model_audit.organization_model_audits.count).to eq 1
        organization_model_audit = new_model_audit.organization_model_audits.first
        expect(organization_model_audit.organization_id).to eq organization.id
        expect(organization_model_audit.bikes_count).to eq 1
        expect(organization_model_audit.certification_status).to be_nil
        expect(organization_model_audit.last_bike_created_at).to be_within(1).of time
      end
      context "likely_spam bike" do
        it "creates an organization_model_audit, updates likely_spam" do
          expect(organization.reload.bikes.pluck(:id)).to eq([bike3.id])
          bike3.update(likely_spam: true)
          expect(Bike.count).to eq 2
          expect(Bike.unscoped.count).to eq 3
          expect {
            instance.perform(nil, bike1.id)
          }.to change(ModelAudit, :count).by 1
          expect(Bike.unscoped.where.not(model_audit_id: nil).count).to eq 3
          new_model_audit = bike1.reload.model_audit
          expect(bike2.reload.model_audit_id).to eq new_model_audit.id
          expect(bike3.reload.model_audit_id).to eq new_model_audit.id
          expect_attrs_to_match_hash(new_model_audit, basic_target_attributes)
          expect(new_model_audit.organization_model_audits.count).to eq 1
          organization_model_audit = new_model_audit.organization_model_audits.first
          expect(organization_model_audit.organization_id).to eq organization.id
          expect(organization_model_audit.bikes_count).to eq 0
          expect(organization_model_audit.certification_status).to be_nil
          expect(organization_model_audit.last_bike_created_at).to be_nil
          # frame_model update, with a frame_model still in model_audit
          expect(new_model_audit.delete_if_no_bikes?).to be_truthy
          bike1.update(frame_model: "Unknown")
          expect(new_model_audit.matching_bike?(bike1)).to be_falsey
          expect(new_model_audit.reload.matching_bikes.pluck(:id)).to match_array([bike2.id, bike3.id])
          instance.perform(nil, bike2.id) # passing bike_id that still matches
          expect(described_class.jobs.count).to eq 1
          described_class.drain # Has to run a second time
          expect(ModelAudit.count).to eq 2
          model_audit_unknown = ModelAudit.order(:id).last
          expect(model_audit_unknown.bikes_count).to eq 1
          expect(model_audit_unknown.matching_bike?(bike1)).to be_truthy
          expect(model_audit_unknown.frame_model).to be_nil
          expect(bike1.reload.model_audit_id).to eq model_audit_unknown.id
          expect(bike2.reload.model_audit_id).to eq new_model_audit.id
          expect(bike3.reload.model_audit_id).to eq new_model_audit.id
          expect(OrganizationModelAudit.count).to eq 2
          organization_model_audit_unknown = OrganizationModelAudit.order(:id).last
          expect(organization_model_audit_unknown.bikes_count).to eq 0
          # frame_model update, with only likely_spam frame_model in model_audit - deletes the model audit
          expect(new_model_audit.matching_bike?(bike2)).to be_truthy
          bike2.update(frame_model: "IDK")
          expect(new_model_audit.matching_bike?(bike2)).to be_falsey

          instance.perform(nil, bike1.id) # passing already updated bike_id
          expect(described_class.jobs.count).to eq 1
          described_class.drain
          expect(ModelAudit.where(id: new_model_audit.id).count).to eq 0
          expect(bike1.reload.model_audit_id).to eq model_audit_unknown.id
          expect(bike2.reload.model_audit_id).to eq model_audit_unknown.id
          expect(bike3.reload.model_audit_id).to be_nil
          expect(OrganizationModelAudit.count).to eq 1
          expect(OrganizationModelAudit.where(id: organization_model_audit.id).count).to eq 0
          expect(organization_model_audit_unknown.reload.bikes_count).to eq 0
        end
      end
      context "frame_model update with model_attestation" do
        let(:model_audit) { FactoryBot.create(:model_audit, frame_model: "Party Frame Model", manufacturer: manufacturer) }
        let!(:model_attestation) { FactoryBot.create(:model_attestation, model_audit: model_audit) }
        it "doesn't delete" do
          expect(organization.reload.bikes.pluck(:id)).to eq([bike3.id])
          bike3.update(user_hidden: true)
          expect(model_audit.delete_if_no_bikes?).to be_falsey
          expect {
            instance.perform(model_audit.id)
            expect(described_class.jobs.count).to eq 2
            described_class.drain
            expect(described_class.jobs.count).to eq 0
          }.to change(ModelAudit, :count).by 1
          expect(Bike.unscoped.where.not(model_audit_id: nil).count).to eq 3
          new_model_audit = bike1.reload.model_audit
          expect(bike2.reload.model_audit_id).to eq new_model_audit.id
          expect(bike3.reload.model_audit_id).to eq new_model_audit.id
          expect_attrs_to_match_hash(new_model_audit, basic_target_attributes.merge(frame_model: "Party MODEL"))
          expect(new_model_audit.organization_model_audits.count).to eq 1
          organization_model_audit = new_model_audit.organization_model_audits.first
          expect(organization_model_audit.organization_id).to eq organization.id
          expect(organization_model_audit.bikes_count).to eq 0 # TODO: Handle user_hidden org bikes
          expect(organization_model_audit.certification_status).to be_nil
          expect(organization_model_audit.last_bike_created_at).to be_nil
          # It still created an organization_model_audit for the empty model_audit
          expect(model_audit.reload.organization_model_audits.count).to eq 1
        end
      end
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
        expect {
          instance.perform(nil, bike1.id)
        }.to change(ModelAudit, :count).by 0
        expect(bike1.reload.model_audit_id).to eq model_audit.id

        expect(bike2.reload.cycle_type).to eq "cargo"
        expect(bike2.propulsion_type).to eq "foot-pedal"
        expect(bike2.model_audit_id).to eq model_audit.id
        expect(model_audit.reload.certification_status).to be_nil
        # Creating a model attestation enqueues job
        expect(described_class.jobs.count).to eq 0
        FactoryBot.create(:model_attestation, model_audit: model_audit, kind: "certified_by_manufacturer")
        expect(described_class.jobs.count).to eq 1
        described_class.drain
        expect(model_audit.reload.certification_status).to eq "certified_by_manufacturer"
      end
      describe "duplicate model_audit" do
        let(:model_audit2) { FactoryBot.create(:model_audit, frame_model: "Party Model", manufacturer: Manufacturer.other, manufacturer_other: "PARty model") }
        it "deletes" do
          expect(bike2.model_audit_id).to be_present
          # It matches, because a matching bike has a model_audit
          bike1.update(model_audit_id: model_audit2.id)
          expect(described_class.enqueue_for?(bike1)).to be_truthy
          Sidekiq::Worker.clear_all
          expect {
            instance.perform(nil, bike1.id)
          }.to change(ModelAudit, :count).by(-1)
          expect(described_class.jobs.count).to eq 1
          described_class.drain
          expect(bike1.reload.model_audit_id).to eq model_audit.id
          expect(bike2.reload.model_audit_id).to eq model_audit.id
          expect(ModelAudit.pluck(:id)).to eq([model_audit.id])
        end
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
        expect(new_model_audit.bikes.count).to eq 2
        # After updating to a known manufacturer, all the bikes update
        bike3.update(manufacturer_id: FactoryBot.create(:manufacturer, name: "Salsa").id)
        expect(new_model_audit.reload.bikes.count).to eq 2
        expect(new_model_audit.matching_bikes.count).to eq 1

        Sidekiq::Worker.clear_all
        instance.perform(new_model_audit.id)
        # Because it re-enqueues
        expect(described_class.jobs.count).to eq 1
        described_class.drain
        expect(described_class.jobs.count).to eq 0
        expect(new_model_audit.reload.manufacturer_id).to eq bike3.manufacturer_id
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
        expect(bike2.model_audit_id).to be_blank
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
