require 'spec_helper'

RSpec.describe CreationState, type: :model do
  describe 'validations' do
    it { is_expected.to belong_to :bike }
    it { is_expected.to belong_to :creator }
    it { is_expected.to belong_to :organization }
  end

  describe 'origin' do
    context 'unknown origin' do
      it 'ignores an unknown origin' do
        creation_state = CreationState.new(origin: 'SOMEwhere', bike_id: 2)
        creation_state.ensure_permitted_origin
        expect(creation_state.origin).to be_nil
      end
    end
    context 'known origin' do
      let(:origin) { CreationState.origins.last }
      it 'uses the origin' do
        creation_state = CreationState.new(origin: origin)
        creation_state.ensure_permitted_origin
        expect(creation_state.origin).to eq origin
      end
    end
    it 'has a before_save callback for ensure_permitted_origin' do
      expect(CreationState._validation_callbacks.select { |cb| cb.kind.eql?(:before) }
        .map(&:raw_filter).include?(:ensure_permitted_origin)).to be_truthy
    end
  end

  describe 'creation_description' do
    context 'bulk' do
      let(:creation_state) { CreationState.new(is_bulk: true, origin: 'api_v12') }
      it 'returns bulk reg' do
        expect(creation_state.creation_description).to eq 'bulk reg'
      end
    end
    context 'pos' do
      let(:creation_state) { CreationState.new(is_pos: true, origin: 'embed_extended') }
      it 'returns pos reg' do
        expect(creation_state.creation_description).to eq 'pos'
      end
    end
    context 'embed_extended' do
      let(:creation_state) { CreationState.new(origin: 'embed_extended') }
      it 'returns pos reg' do
        expect(creation_state.creation_description).to eq 'embed extended'
      end
    end
    context 'nil' do
      let(:creation_state) { CreationState.new(organization_id: 1, creator_id: 1) }
      it 'returns nil' do
        expect(creation_state.creation_description).to be_nil
      end
    end
  end

  describe 'create_bike_organization' do
    let(:bike) { FactoryGirl.create(:bike) }
    let(:organization) { FactoryGirl.create(:organization) }
    context 'no organization' do
      let(:creation_state) { FactoryGirl.create(:creation_state, bike: bike) }
      it 'returns true' do
        expect do
          creation_state.create_bike_organization
        end.to change(BikeOrganization, :count).by 0
      end
    end
    context 'with organization' do
      let(:creation_state) { FactoryGirl.create(:creation_state, bike: bike) }
      it 'creates the bike_organization' do
        creation_state.organization = organization
        expect do
          creation_state.create_bike_organization
        end.to change(BikeOrganization, :count).by 1
        expect(bike.bike_organizations.first.organization).to eq organization
      end
    end
    context 'already existing bike_organization' do
      let(:creation_state) { FactoryGirl.create(:creation_state, bike: bike) }
      it 'does not error or duplicate' do
        FactoryGirl.create(:bike_organization, bike: bike, organization: organization)
        creation_state.organization = organization
        expect do
          creation_state.create_bike_organization
        end.to change(BikeOrganization, :count).by 0
      end
    end
    it 'has an after_create callback' do
      expect(CreationState._create_callbacks.select { |cb| cb.kind.eql?(:after) }
        .map(&:raw_filter).include?(:create_bike_organization)).to eq(true)
    end
  end

  context 'set_reflexive_association' do
    it 'sets the creation_state_id on bike' do
      creation_state = FactoryGirl.create(:creation_state)
      bike = creation_state.bike
      bike.reload
      expect(bike.creation_state_id).to eq creation_state.id
    end
    it 'has an after_save callback' do
      expect(CreationState._save_callbacks.select { |cb| cb.kind.eql?(:after) }
        .map(&:raw_filter).include?(:set_reflexive_association)).to eq(true)
    end
  end
end
