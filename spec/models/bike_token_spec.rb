require 'spec_helper'

describe BikeToken do

  describe :validations do
    it { should belong_to :bike }
    it { should belong_to :user }
    it { should belong_to :organization }
    it { should validate_presence_of :user }
    it { should validate_presence_of :organization }
  end

  describe :used_at do
    before :each do
      @bike_token = FactoryGirl.create(:bike_token)
      @bike = FactoryGirl.create(:bike)
      @bike2 = FactoryGirl.create(:bike)
    end

    it "sets the used_at timestamp when used" do
      @bike_token.used_at.should be_nil
      @bike_token.bike = @bike
      @bike_token.save
      @bike.reload.creation_organization.should_not be_nil
      @bike_token.used_at.should_not be_nil
      time = @bike_token.used_at
      @bike_token.bike = @bike2
      @bike_token.save
      @bike_token.used_at.should eq(time)
    end
  end

end
