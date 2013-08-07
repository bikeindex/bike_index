require 'spec_helper'

describe BikeCreatorTokenizer do

  describe :untokenize do
    it "should remove the token attributes" do 
      bike = Bike.new(created_with_token: true, bike_token_id: 2)
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.untokenize
      bike.bike_token_id.should be_nil
      bike.created_with_token.should be_false
    end
  end

  describe :use_token do
    it "should mark the bike tokened" do 
      bike_token = BikeToken.new 
      bike = Bike.new(payment_required: true)
      b_param = FactoryGirl.create(:b_param, params: {stolen: false})
      bike_token.stub(:organization_id).and_return(42)
      bike_token.stub(:id).and_return(2)
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.use_token(bike_token)
      bike.bike_token_id.should eq(2)
      bike.created_with_token.should be_true
      bike.payment_required.should be_false 
      bike.verified.should be_true
      bike.creation_organization_id.should eq(42)
      bike.verified.should be_true
      b_param.reload.bike_token_id.should eq(2)
    end
  end

  describe :tokenize do 
    it "should find the bike token and call use token if token is usable" do
      bike = Bike.new
      b_param = BParam.new
      bike_token = BikeToken.new
      bike_token.stub(:id).and_return(2)
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.should_receive(:find_token).and_return(bike_token)
      creator.should_receive(:token_usable).with(bike_token).and_return(true)
      creator.should_receive(:use_token).with(bike_token).and_return(bike_token)
      creator.tokenize(2)
    end
  end

  describe :find_token do 
    it "should add an error to the bike if the token doesn't exist" do 
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.find_token(2).should be_false
      bike.errors[:bike_token].should_not be_nil
    end
    it "should find the token and return it" do 
      bike = Bike.new
      b_param = BParam.new
      bike_token = FactoryGirl.create(:bike_token)
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.find_token(bike_token.id).should eq(bike_token)
    end
  end

  describe :token_usable do 
    it "should add an error if the creator isn't the owner" do
      bike = Bike.new
      b_param = BParam.new
      bike_token = BikeToken.new
      b_param.stub(:used?).and_return(false)
      bike_token.stub(:user).and_return("Georgafina")
      b_param.stub(:creator).and_return("Natalie")
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.token_usable(bike_token).should be_false
      bike.errors[:bike_token].should_not be_nil
    end
    it "should add an error if the token is used" do 
      bike = Bike.new
      b_param = BParam.new
      bike_token = BikeToken.new
      b_param.stub(:creator).and_return("Georgafina")
      bike_token.stub(:user).and_return("Georgafina")
      bike_token.stub(:used?).and_return(true)
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.token_usable(bike_token).should be_false
      bike.errors[:bike_token].should_not be_nil
    end
    it "should return true" do 
      bike = Bike.new
      b_param = BParam.new
      bike_token = BikeToken.new
      bike_token.stub(:used?).and_return(false)
      bike_token.stub(:user).and_return("Georgafina")
      b_param.stub(:creator).and_return("Georgafina")
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.token_usable(bike_token).should be_true
    end
  end

  describe :check_token do
    it "should return false if bike token is not present" do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.should_receive(:untokenize).and_return(true)
      creator.check_token
    end

    it "should call tokenize with the token if it's on b_param" do 
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:bike_token_id).and_return(69)
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.should_receive(:tokenize).with(69).and_return(true)
      creator.check_token
    end

    it "should call tokenize with the token if it's in the params" do 
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:params).and_return(bike_token_id: 69)
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.should_receive(:tokenize).with(69).and_return(true)
      creator.check_token
    end

    it "should call tokenize with the token if it's in the bike params" do 
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:params).and_return(:bike => {bike_token_id: 69})
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.should_receive(:tokenize).with(69)
      creator.check_token
    end
  end

  describe :tokenized_bike do 
    it "should untokenize if there are errors and return the bike" do 
      bike = Bike.new(description: "Special description")
      bike.errors.add(:bike_token, "Oh no, you've already used that free bike ticket!")
      b_param = BParam.new
      creator = BikeCreatorTokenizer.new(b_param, bike)
      creator.should_receive(:check_token).and_return(true)
      creator.should_receive(:untokenize).and_return(true)
      creator.tokenized_bike.should eq(bike)
    end
  end

end