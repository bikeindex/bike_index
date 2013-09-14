require 'spec_helper'

describe BikeCreatorVerifier do

  describe :set_no_payment_required do 
    it "should set payment required on the bike" do
      bike = Bike.new
      b_param = BParam.new 
      creator = BikeCreatorVerifier.new(b_param, bike).set_no_payment_required
      bike.payment_required.should be_false
      bike.verified.should be_true
    end
  end

  describe :stolenize do 
    it "should mark the bike stolen and payment required false" do 
      bike = Bike.new
      b_param = BParam.new
      BikeCreatorVerifier.new(b_param, bike).stolenize
      bike.stolen.should be_true
      bike.payment_required.should be_false
    end
  end

  describe :check_token do
    it "should set the bike to what BikeCreatorTokenizer returns" do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorVerifier.new(b_param, bike)
      BikeCreatorTokenizer.any_instance.should_receive(:tokenized_bike).and_return(bike)
      creator.check_token.should eq(bike)
    end
  end

  describe :check_organization do
    it "should set the bike to what BikeCreatorTokenizer returns" do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorVerifier.new(b_param, bike)
      BikeCreatorOrganizer.any_instance.should_receive(:organized_bike).and_return(bike)
      creator.check_organization.should eq(bike)
    end
  end

  describe :check_stolen do 
    it "should return false if the bike isn't stolen" do
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorVerifier.new(b_param, bike).check_stolen
      creator.should be_false
    end
    it "should call stolenize if there is a stolen attribute included" do
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:params).and_return(:bike => {stolen: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:stolenize).and_return(true)
      creator.check_stolen
    end
    it "should call stolenize if the stolen parameter is passed" do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:stolenize).and_return(true)
      creator.check_stolen
    end
  end

  describe :verify do
    it "should call the methods it needs to call" do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:set_no_payment_required).and_return(true)
      creator.should_receive(:check_token).and_return(true) 
      creator.should_receive(:check_stolen).and_return(true)
      creator.verify.should eq(bike)
    end
  end


end