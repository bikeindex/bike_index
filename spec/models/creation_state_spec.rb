require "spec_helper"

RSpec.describe CreationState, type: :model do
  describe "set_calculated_attributes" do
    context "unknown origin" do
      it "ignores an unknown origin" do
        creation_state = CreationState.new(origin: "SOMEwhere", bike_id: 2)
        creation_state.set_calculated_attributes
        expect(creation_state.origin).to be_nil
      end
    end
    context "known origin" do
      let(:origin) { CreationState.origins.last }
      it "uses the origin" do
        creation_state = CreationState.new(origin: origin)
        creation_state.set_calculated_attributes
        expect(creation_state.origin).to eq origin
      end
    end
  end

  describe "creation_description" do
    let(:creation_state) { CreationState.new(organization_id: 1, creator_id: 1) }
    it "returns nil" do
      expect(creation_state.creation_description).to be_nil
    end
    context "bulk" do
      let(:creation_state) { CreationState.new(is_bulk: true, origin: "api_v12") }
      it "returns bulk reg" do
        expect(creation_state.creation_description).to eq "bulk reg"
        expect(creation_state.is_pos).to be_falsey
      end
    end
    context "pos" do
      let(:creation_state) { CreationState.new(is_pos: true, pos_kind: "lightspeed_pos", origin: "embed_extended") }
      before { creation_state.set_calculated_attributes }
      it "returns pos reg" do
        expect(creation_state.creation_description).to eq "Lightspeed"
      end
      context "ascend" do
        let(:bulk_import) { BulkImport.new(is_ascend: true) }
        let(:creation_state) { CreationState.new(bulk_import: bulk_import) }
        it "returns pos reg" do
          expect(creation_state.creation_description).to eq "Ascend"
        end
      end
    end
    context "embed_extended" do
      let(:creation_state) { CreationState.new(origin: "embed_extended") }
      it "returns pos reg" do
        expect(creation_state.creation_description).to eq "embed extended"
      end
    end
  end

  describe "calculated_pos_kind" do
    let(:creation_state) { CreationState.new }
    it "returns not_pos" do
      expect(creation_state.send("calculated_pos_kind")).to eq "not_pos"
    end
    context "is_pos" do
      # We're defaulting to Lightspeed right now, because it's what exists in the database
      # TODO: make it so we explicitly set bikes to lightspeed_pos from the integration, and all others to other_pos
      let(:creation_state) { CreationState.new(is_pos: true) }
      it "returns lightspeed" do
        expect(creation_state.send("calculated_pos_kind")).to eq "lightspeed_pos"
      end
    end
    context "ascend bulk import" do
      let(:bulk_import) { BulkImport.new(is_ascend: true) }
      let(:creation_state) { CreationState.new(bulk_import: bulk_import) }
      it "returns ascend" do
        expect(bulk_import.ascend?).to be_truthy
        expect(creation_state.is_pos).to be_falsey
        expect(creation_state.send("calculated_pos_kind")).to eq "ascend_pos"
        expect(creation_state.is_pos).to be_truthy
      end
    end
  end

  describe "create_bike_organization" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:organization) { FactoryBot.create(:organization) }
    context "no organization" do
      let(:creation_state) { FactoryBot.create(:creation_state, bike: bike) }
      it "returns true" do
        expect do
          creation_state.create_bike_organization
        end.to change(BikeOrganization, :count).by 0
      end
    end
    context "with organization" do
      let(:creation_state) { FactoryBot.create(:creation_state, bike: bike) }
      it "creates the bike_organization" do
        creation_state.organization = organization
        expect do
          creation_state.create_bike_organization
        end.to change(BikeOrganization, :count).by 1
        expect(bike.bike_organizations.first.organization).to eq organization
      end
    end
    context "parent organization" do
      it "creates the bike_organization for both" do
      end
    end
    context "already existing bike_organization" do
      let(:creation_state) { FactoryBot.create(:creation_state, bike: bike) }
      it "does not error or duplicate" do
        FactoryBot.create(:bike_organization, bike: bike, organization: organization)
        creation_state.organization = organization
        expect do
          creation_state.create_bike_organization
        end.to change(BikeOrganization, :count).by 0
      end
    end
    it "has an after_create callback" do
      expect(CreationState._create_callbacks.select { |cb| cb.kind.eql?(:after) }
        .map(&:raw_filter).include?(:create_bike_organization)).to eq(true)
    end
  end

  context "set_reflexive_association" do
    it "sets the creation_state_id on bike" do
      creation_state = FactoryBot.create(:creation_state)
      bike = creation_state.bike
      bike.reload
      expect(bike.creation_state_id).to eq creation_state.id
    end
    it "has an after_save callback" do
      expect(CreationState._save_callbacks.select { |cb| cb.kind.eql?(:after) }
        .map(&:raw_filter).include?(:set_reflexive_association)).to eq(true)
    end
  end
end
