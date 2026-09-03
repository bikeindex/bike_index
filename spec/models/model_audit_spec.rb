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
        expect(ModelAudit.unknown_model?(bike.frame_model, manufacturer_id: 42)).to be_truthy
        expect(ModelAudit.audit?(bike)).to be_truthy
      end
    end
    context "not motorized" do
      let(:manufacturer) { FactoryBot.create(:manufacturer) }
      let(:bike) { FactoryBot.build(:bike, frame_model: frame_model, propulsion_type: "hand-pedal", manufacturer: manufacturer) }
      let(:frame_model) { "unkown" }
      it "returns false" do
        expect(ModelAudit.unknown_model?(bike.frame_model, manufacturer_id: 42)).to be_truthy
        expect(ModelAudit.audit?(bike)).to be_falsey
      end
      context "with manufacturer motorized_only" do
        let(:manufacturer) { FactoryBot.create(:manufacturer, motorized_only: true) }
        let(:frame_model) { nil }
        it "returns true" do
          expect(ModelAudit.unknown_model?(bike.frame_model, manufacturer_id: 42)).to be_truthy
          expect(ModelAudit.audit?(bike)).to be_truthy
        end
      end
      context "existing model_audit" do
        let!(:existing_bike) { FactoryBot.create(:bike, manufacturer: manufacturer, frame_model: frame_model, model_audit_id: 12) }
        it "returns false" do
          expect(ModelAudit.unknown_model?(bike.frame_model, manufacturer_id: 42)).to be_truthy
          expect(ModelAudit.audit?(bike)).to be_falsey
        end
        context "with not unknown frame_model" do
          let(:frame_model) { "something" }
          it "returns true" do
            expect(ModelAudit.unknown_model?(bike.frame_model, manufacturer_id: 42)).to be_falsey
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
        expect(ModelAudit.unknown_model?(bike1.frame_model, manufacturer_id: 42)).to be_truthy
        expect(bike6.manufacturer_id).to_not eq manufacturer.id
        (Bike.pluck(:frame_model) - ["none coolest"]).each do |frame_model|
          expect(ModelAudit.unknown_model?(frame_model, manufacturer_id: 42)).to be_truthy
        end
        expect(ModelAudit.unknown_model?(bike_known.frame_model, manufacturer_id: 42)).to be_falsey
        expect(ModelAudit.matching_bikes_for(bike1).pluck(:id)).to match_array([bike1.id, bike5.id])
        # TODO: This seems weird - it probably should return empty...
        expect(ModelAudit.matching_bikes_for(bike2).pluck(:id)).to match_array([bike1.id, bike2.id, bike5.id])
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
    let(:bike) { Bike.new(manufacturer: manufacturer, frame_model: model_audit.frame_model.upcase, mnfg_name: manufacturer.short_name) }
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

  describe "private unknown_model methods" do
    # These private methods are tested because regular expressions are hard,
    # I wanted test cases to show the intention and help make future bug fixing easier
    describe "normalize_model_string" do
      it "removes non-letters/numbers" do
        expect(described_class.send(:normalize_model_string, "e-bike ")).to eq "ebike"
        expect(described_class.send(:normalize_model_string, " n/a\n")).to eq "na"
        expect(described_class.send(:normalize_model_string, "123_party")).to eq "123party"
      end
    end
    describe "model_bare_vehicle_type?" do
      it "matches on vehicle types and electric" do
        # sanity check that we're not matching "rear" because of a bad split
        expect(described_class.send(:vehicle_type_strings)).not_to include("rear")
        expect(described_class.send(:model_bare_vehicle_type?, "\nbicycle ")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "tandem")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "e-bike ")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "e-fat bike ")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, " midstep electricbicycle ")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "TRIcycle ")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "e-trike ")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "electric cargo trike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "electric cargoite")).to be_falsey
        expect(described_class.send(:model_bare_vehicle_type?, "cargo midtail bike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "cargod")).to be_falsey
        expect(described_class.send(:model_bare_vehicle_type?, "cargo-tricycle")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "tandem electric")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "unicycle")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "wheelchair")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "estroller")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "electric_cargobike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "motorcycle")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "dirtbike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "e-Three Wheeler")).to be_truthy
      end

      it "matches vehicle varieties combined with vehicle types" do
        expect(described_class.send(:model_without_varieties, "men's")).to eq ""
        expect(described_class.send(:model_without_varieties, "mens electric")).to eq ""
        expect(described_class.send(:model_without_varieties, "mens electric CARGO")).to eq ""
        expect(described_class.send(:model_without_varieties, "lady sm cargo electric")).to eq ""
        expect(described_class.send(:model_without_varieties, "ladys MD")).to eq ""
        expect(described_class.send(:model_without_varieties, "ladys MeDium\t road bike")).to eq "bike"
        expect(described_class.send(:model_without_varieties, "male lag longtail")).to eq "lag"
        expect(described_class.send(:model_without_varieties, "male fat tire")).to eq ""
        expect(described_class.send(:model_bare_vehicle_type?, " Women's lg frame step in")).to be_truthy

        expect(described_class.send(:model_without_varieties, "folding large cargo electricdd")).to eq "dd"
        expect(described_class.send(:model_without_varieties, "utility xxl cargo electric X.X_2")).to eq "x-x-2"

        expect(described_class.send(:model_bare_vehicle_type?, "high.step city bike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "commuter trike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "traditional folding bike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "mtb (yellow)")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "Aluminum Mountain-bicycle")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "hybrid electric-cruiser bike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "electric-step-through")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "xs mtb 3_wheeler")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "bmx\tbike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "electric-utility-trike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "silver  Men's bike")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, "\ngreen ladies unicycle")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, " stepthru folding bike frame\n")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, " ladies step through regular frame\n")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, " ladies step-thru foldable\ntrike ")).to be_truthy
        expect(described_class.send(:model_bare_vehicle_type?, " XP Step-Thru 3.0\n")).to be_falsey

        expect(described_class.send(:model_bare_vehicle_type?, " Full Suspension e-bike\n")).to be_truthy
      end
    end
  end

  describe "unknown_model" do
    it "is false" do
      expect(described_class.unknown_model?("bike 200", manufacturer_id: 42)).to be_falsey
    end
    it "matches unknown" do
      expect(described_class.unknown_model?("na", manufacturer_id: 42)).to be_truthy
      expect(described_class.unknown_model?("No model", manufacturer_id: 42)).to be_truthy
      expect(described_class.unknown_model?("unkown", manufacturer_id: 42)).to be_truthy
      expect(described_class.unknown_model?("medium", manufacturer_id: 42)).to be_truthy
    end
    it "matches cycle types" do
      expect(described_class.unknown_model?("eScooter", manufacturer_id: 42)).to be_truthy
      expect(described_class.unknown_model?("electric-mens MTB", manufacturer_id: 42)).to be_truthy
      expect(described_class.unknown_model?("purple small cargo-bike", manufacturer_id: 42)).to be_truthy
      expect(described_class.unknown_model?("RED XXL electric Mountain", manufacturer_id: 42)).to be_truthy
    end
    context "when named the same as the manufacturer" do
      let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
      it "matches" do
        expect(described_class.unknown_model?(" salsa", manufacturer_id: 42)).to be_falsey
        expect(described_class.unknown_model?(" salsa", manufacturer_id: manufacturer.id)).to be_truthy
        expect(described_class.unknown_model?(" salsa bike", manufacturer_id: manufacturer.id)).to be_truthy
      end

      context "with secondary name" do
        let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "CVLN (Civilian)") }
        it "matches for both name and secondary" do
          expect(described_class.unknown_model?(" CVLN", manufacturer_id: 42)).to be_falsey
          expect(described_class.unknown_model?(" cvln", manufacturer_id: manufacturer.id)).to be_truthy
          expect(described_class.unknown_model?(" civilian\n", manufacturer_id: manufacturer.id)).to be_truthy
          expect(described_class.unknown_model?(" civilian bicycle", manufacturer_id: manufacturer.id)).to be_truthy
        end
      end
    end
  end
end
