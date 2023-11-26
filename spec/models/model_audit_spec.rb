require "rails_helper"

RSpec.describe ModelAudit, type: :model do
  describe "factory" do
    let(:model_audit) { FactoryBot.create(:model_audit) }
    it "is valid" do
      expect(model_audit).to be_valid
    end
    context "case_sensitive" do
      let(:model_audit_dupe) { FactoryBot.build(:model_audit, manufacturer: model_audit.manufacturer, frame_model: model_audit.frame_model.upcase) }
      it "doesn't duplicate" do
        expect(model_audit).to be_valid
        expect(model_audit_dupe).to_not be_valid
        expect(model_audit_dupe.errors.full_messages).to eq(["Frame model has already been taken"])
      end
    end
  end

  describe "calculated_certification_status" do
    let(:model_audit) { FactoryBot.create(:model_audit) }
    let!(:model_attestation) { FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certification_proof_url) }
    it "returns the most important attestation" do
      expect(model_audit.reload.send(:calculated_certification_status)).to be_nil

      FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certified_by_manufacturer)
      expect(model_audit.reload.send(:calculated_certification_status)).to eq "certified_by_manufacturer"

      FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :certified_by_trusted_org)
      expect(model_audit.reload.send(:calculated_certification_status)).to eq "certified_by_trusted_org"

      FactoryBot.create(:model_attestation, model_audit: model_audit, kind: :uncertified_by_trusted_org)
      expect(model_audit.reload.send(:calculated_certification_status)).to eq "uncertified_by_trusted_org"

      # It assigns on save
      model_audit.update(updated_at: Time.current)
      expect(model_audit.certification_status).to eq "uncertified_by_trusted_org"
    end
  end

  describe "audit?" do
    let(:bike) { Bike.new(propulsion_type: "foot-pedal", model_audit_id: 11) }
    it "returns false" do
      expect(ModelAudit.audit?(bike)).to be_falsey
    end
    context "motorized" do
      let(:bike) { Bike.new(propulsion_type: "throttle") }
      it "returns true" do
        expect(ModelAudit.unknown_model?(bike.frame_model)).to be_truthy
        expect(ModelAudit.audit?(bike)).to be_truthy
      end
    end
    context "not motorized" do
      let(:manufacturer) { FactoryBot.create(:manufacturer) }
      let(:bike) { FactoryBot.build(:bike, frame_model: frame_model, propulsion_type: "hand-pedal", manufacturer: manufacturer) }
      let(:frame_model) { "unkown" }
      it "returns false" do
        expect(ModelAudit.unknown_model?(bike.frame_model)).to be_truthy
        expect(ModelAudit.audit?(bike)).to be_falsey
      end
      context "with manufacturer motorized_only" do
        let(:manufacturer) { FactoryBot.create(:manufacturer, motorized_only: true) }
        let(:frame_model) { nil }
        it "returns true" do
          expect(ModelAudit.unknown_model?(bike.frame_model)).to be_truthy
          expect(ModelAudit.audit?(bike)).to be_truthy
        end
      end
      context "existing model_audit" do
        let!(:existing_bike) { FactoryBot.create(:bike, manufacturer: manufacturer, frame_model: frame_model, model_audit_id: 12) }
        it "returns false" do
          expect(ModelAudit.unknown_model?(bike.frame_model)).to be_truthy
          expect(ModelAudit.audit?(bike)).to be_falsey
        end
        context "with not unknown frame_model" do
          let(:frame_model) { "something" }
          it "returns true" do
            expect(ModelAudit.unknown_model?(bike.frame_model)).to be_falsey
            expect(ModelAudit.audit?(bike)).to be_truthy
          end
        end
      end
    end
  end

  describe "matching_bikes_for" do
    context "frame model nil" do
      let(:bike1) { FactoryBot.create(:bike, frame_model: nil, propulsion_type: "pedal-assist") }
      let(:manufacturer) { bike1.manufacturer }
      let!(:bike2) { FactoryBot.create(:bike, frame_model: "na", manufacturer: manufacturer) }
      let!(:bike3) { FactoryBot.create(:bike, frame_model: "UNknown", manufacturer: manufacturer) }
      let!(:bike4) { FactoryBot.create(:bike, frame_model: "TBD ", manufacturer: manufacturer) }
      let!(:bike5) { FactoryBot.create(:bike, frame_model: "idk ", propulsion_type: "throttle", manufacturer: manufacturer) }
      let!(:bike6) { FactoryBot.create(:bike, frame_model: "No model") }
      let!(:bike_known) { FactoryBot.create(:bike, frame_model: "none coolest", manufacturer: manufacturer) }
      it "finds the matches" do
        expect(ModelAudit.unknown_model?(bike1.frame_model)).to be_truthy
        expect(bike6.manufacturer_id).to_not eq manufacturer.id
        (Bike.pluck(:frame_model) - ["none coolest"]).each do |frame_model|
          expect(ModelAudit.unknown_model?(frame_model)).to be_truthy
        end
        expect(ModelAudit.unknown_model?(bike_known.frame_model)).to be_falsey
        expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike5.id])
        # TODO: This seems weird - it probably should return empty...
        expect(ModelAudit.matching_bikes_for(bike2).pluck(:id)).to match_array([bike1.id, bike5.id])
        # But - if you update to be motorized, it's all the bikes
        manufacturer.update(motorized_only: true)
        expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id, bike4.id, bike5.id])
      end
    end
  end

  describe "manufacturer_id_corrected" do
    context "with matching manufacturer" do
      let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Specialized bikes") }
      it "returns manufacturer_id" do
        expect(ModelAudit.manufacturer_id_corrected(manufacturer.id, "Specialized")).to eq manufacturer.id
        expect(ModelAudit.manufacturer_id_corrected(Manufacturer.other.id, "Specialized")).to eq manufacturer.id
      end
    end
    context "other" do
      let!(:manufacturer) { Manufacturer.other }
      it "returns manufacturer other id" do
        expect(ModelAudit.manufacturer_id_corrected(manufacturer.id, "Specialized")).to eq manufacturer.id
      end
    end
  end

  describe "find_for" do
    let!(:model_audit) { FactoryBot.create(:model_audit, manufacturer: manufacturer) }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:bike) { Bike.new(manufacturer: manufacturer, frame_model: model_audit.frame_model.upcase, mnfg_name: manufacturer.simple_name) }
    it "finds the matching model_audit" do
      expect(ModelAudit.find_for(bike)&.id).to eq model_audit.id
    end
    context "manufacturer_other and unknown_model" do
      let!(:model_audit) { FactoryBot.create(:model_audit, manufacturer: Manufacturer.other, manufacturer_other: "Some Cool Name", frame_model: nil) }
      let(:bike) { Bike.new(frame_model: "NA", manufacturer: Manufacturer.other, mnfg_name: "Some cool name") }
      it "finds the matching model_audit" do
        expect(ModelAudit.matching_manufacturer(Manufacturer.other.id, "Some Cool NAME").pluck(:id)).to eq([model_audit.id])
        expect(ModelAudit.find_for(bike)&.id).to eq model_audit.id
      end
    end
    context "manufacturer_other matching manufacturer" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "BH Bikes (Beistegui Hermanos)") }
      let(:bike) { Bike.new(frame_model: model_audit.frame_model.upcase, manufacturer: Manufacturer.other, mnfg_name: "BH") }
      it "finds the matching model_audit" do
        expect(ModelAudit.find_for(bike)&.id).to eq model_audit.id
      end
      context "existing manufacturer_other" do
        let!(:model_audit) { FactoryBot.create(:model_audit, manufacturer: Manufacturer.other, frame_model: "Cool name") }
        let(:model_audit_later) { FactoryBot.create(:model_audit, manufacturer: manufacturer, frame_model: "Cool name") }
        before do
          model_audit
          model_audit_later
        end
        it "finds the model_audit with manufacturer_id not other" do
          expect(model_audit_later.id).to be > model_audit.id
          expect(ModelAudit.find_for(bike)&.id).to eq model_audit_later.id
          expect(ModelAudit.find_for(nil, manufacturer_id: manufacturer, frame_model: "COOL NAme")&.id).to eq model_audit_later.id
        end
      end
    end
  end

  describe "delete_if_no_bikes?" do
    let(:model_audit) { FactoryBot.create(:model_audit) }
    it "returns true" do
      expect(model_audit.reload.delete_if_no_bikes?).to be_truthy
    end
    context "with_model_attestations" do
      let!(:model_attestation) { FactoryBot.create(:model_attestation, model_audit: model_audit) }
      it "returns false" do
        expect(model_audit.reload.delete_if_no_bikes?).to be_falsey
      end
    end
  end
end
