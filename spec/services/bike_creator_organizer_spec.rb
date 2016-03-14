require 'spec_helper'

describe BikeCreatorOrganizer do

  describe :unorganize do
    it "removes the token attributes" do 
      bike = Bike.new(creation_organization_id: 4)
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.unorganize
      bike.creation_organization_id.should be_nil
    end
  end

  describe :use_organization do
    it "marks the bike organized" do 
      bike_token = BikeToken.new 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      organization = Organization.new 
      organization.stub(:id).and_return(2)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.use_organization(organization)
      bike.creation_organization_id.should eq(2)
    end
  end

  describe :organize do 
    it "finds the organization and call use organization if it's usable" do
      bike = Bike.new
      b_param = BParam.new
      organization = Organization.new
      organization.stub(:id).and_return(2)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.should_receive(:find_organization).and_return(organization)
      creator.should_receive(:organization_usable).with(organization).and_return(true)
      creator.should_receive(:use_organization).with(organization).and_return(organization)
      creator.organize(2)
    end
  end

  describe :find_organization do 
    it "adds an error to the bike if the organization doesn't exist" do 
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.find_organization(2).should be_false
      bike.errors[:organization].should_not be_nil
    end
    it "finds the organization and return it" do 
      bike = Bike.new
      b_param = BParam.new
      organization = FactoryGirl.create(:organization)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.find_organization(organization.id).should eq(organization)
    end
  end

  describe :organization_usable do 
    it "adds an error if the creator doesn't have a membership to the organization and the bike isn't created with a bike token" do
      bike = Bike.new
      b_param = BParam.new
      organization = BikeToken.new
      user = User.new
      organization.stub(:is_suspended).and_return(false)
      organization.stub(:name).and_return("Ballsy")
      bike.stub(:created_with_token).and_return(false)
      b_param.stub(:creator).and_return(user)
      user.stub(:is_member_of?).and_return(false)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.organization_usable(organization).should be_false
      bike.errors[:creation_organization].should_not be_nil
    end
    it "adds an error if the organization is suspended is used" do 
      bike = Bike.new
      b_param = BParam.new
      organization = BikeToken.new
      bike.stub(:created_with_token).and_return(true)
      organization.stub(:name).and_return("Ballsy")
      organization.stub(:is_suspended).and_return(true)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.organization_usable(organization).should be_false
      bike.errors[:creation_organization].should_not be_nil
    end

    it "returns true" do
      bike = Bike.new
      b_param = BParam.new
      organization = BikeToken.new
      user = User.new
      organization.stub(:is_suspended).and_return(false)
      organization.stub(:name).and_return("Ballsy")
      bike.stub(:created_with_token).and_return(false)
      b_param.stub(:creator).and_return(user)
      user.stub(:is_member_of?).and_return(true)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.organization_usable(organization).should be_true
    end
  end

  describe :check_organization do
    it "returns false if organization is not present" do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.should_receive(:unorganize).and_return(true)
      creator.check_organization
    end

    it "calls organize with the organization id if if it's in the params" do 
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:params).and_return(creation_organization_id: 69)
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.should_receive(:organize).with(69).and_return(true)
      creator.check_organization
    end

    it "calls organize with the org if it's in the bike params" do 
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:params).and_return(bike: {creation_organization_id: 69})
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.should_receive(:organize).with(69)
      creator.check_organization
    end
  end

  describe :organized_bike do 
    it "unorganizes if there are errors and return the bike" do
      bike = Bike.new(created_with_token: false)
      bike.errors.add(:creation_organization, "Oh no, wrong org")
      b_param = BParam.new
      creator = BikeCreatorOrganizer.new(b_param, bike)
      creator.should_receive(:check_organization).and_return(true)
      creator.should_receive(:unorganize).and_return(true)
      creator.organized_bike.should eq(bike)
    end
  end

end
