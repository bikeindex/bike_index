require 'spec_helper'

describe BikeCreatorOrganizer do
  describe 'unorganize' do
    it 'removes the token attributes' do
      bike = Bike.new(creation_organization_id: 4)
      b_param = BParam.new(params: { stolen: false })
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.unorganize
      expect(bike.creation_organization_id).to be_nil
    end
  end

  describe 'use_organization' do
    it 'marks the bike organized' do
      bike = Bike.new
      b_param = BParam.new(params: { stolen: false })
      organization = Organization.new
      allow(organization).to receive(:id).and_return(2)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.use_organization(organization)
      expect(bike.creation_organization_id).to eq(2)
    end
  end

  describe 'organize' do
    it "finds the organization and call use organization if it's usable" do
      bike = Bike.new
      b_param = BParam.new
      organization = Organization.new
      allow(organization).to receive(:id).and_return(2)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator).to receive(:find_organization).and_return(organization)
      expect(creator).to receive(:organization_usable).with(organization).and_return(true)
      expect(creator).to receive(:use_organization).with(organization).and_return(organization)
      creator.organize(2)
    end
  end

  describe 'find_organization' do
    it "adds an error to the bike if the organization doesn't exist" do
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator.find_organization(2)).to be_falsey
      expect(bike.errors[:organization]).not_to be_nil
    end
    it 'finds the organization and return it' do
      bike = Bike.new
      b_param = BParam.new
      organization = FactoryGirl.create(:organization)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator.find_organization(organization.id)).to eq(organization)
    end
  end

  describe 'organization_usable' do
    it "adds an error if the creator doesn't have a membership to the organization" do
      bike = Bike.new
      b_param = BParam.new
      user = User.new
      organization = Organization.new
      allow(organization).to receive(:is_suspended).and_return(false)
      allow(organization).to receive(:name).and_return('Ballsy')
      allow(b_param).to receive(:creator).and_return(user)
      allow(user).to receive(:is_member_of?).and_return(false)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator.organization_usable(organization)).to be_falsey
      expect(bike.errors[:creation_organization]).not_to be_nil
    end
    it 'adds an error if the organization is suspended is used' do
      bike = Bike.new
      b_param = BParam.new
      user = User.new
      organization = Organization.new
      allow(b_param).to receive(:creator).and_return(user)
      allow(user).to receive(:is_member_of?).and_return(true)
      allow(organization).to receive(:name).and_return('Ballsy')
      allow(organization).to receive(:is_suspended).and_return(true)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator.organization_usable(organization)).to be_falsey
      expect(bike.errors[:creation_organization]).not_to be_nil
    end
    it 'returns true' do
      bike = Bike.new
      b_param = BParam.new
      user = User.new
      organization = Organization.new
      allow(organization).to receive(:is_suspended).and_return(false)
      allow(organization).to receive(:name).and_return('Ballsy')
      allow(b_param).to receive(:creator).and_return(user)
      allow(user).to receive(:is_member_of?).and_return(true)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator.organization_usable(organization)).to be_truthy
    end
  end

  describe 'check_organization' do
    it 'returns false if organization is not present' do
      bike = Bike.new
      b_param = BParam.new(params: { stolen: false })
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator).to receive(:unorganize).and_return(true)
      creator.check_organization
    end

    it "calls organize with the organization id if if it's in the params" do
      bike = Bike.new
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return(creation_organization_id: 69)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator).to receive(:organize).with(69).and_return(true)
      creator.check_organization
    end

    it "calls organize with the org if it's in the bike params" do
      bike = Bike.new
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return(bike: { creation_organization_id: 69 })
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator).to receive(:organize).with(69)
      creator.check_organization
    end
  end

  describe 'organized_bike' do
    it 'unorganizes if there are errors and return the bike' do
      bike = Bike.new
      bike.errors.add(:creation_organization, 'Oh no, wrong org')
      b_param = BParam.new
      creator = BikeCreatorOrganizer.new(b_param, bike)
      expect(creator).to receive(:check_organization).and_return(true)
      expect(creator).to receive(:unorganize).and_return(true)
      expect(creator.organized_bike).to eq(bike)
    end
  end
end
