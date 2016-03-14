require 'spec_helper'

describe BikeCreatorVerifier do

  describe :add_phone do 
    it 'calls add the org phone if one exists' do 
      bike = Bike.new
      organization = Organization.new
      location = Location.new
      b_param = BParam.new
      organization.stub(:locations).and_return([location])
      location.stub(:phone).and_return('6969')
      bike.stub(:creation_organization).and_return(organization)
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.add_phone
      bike.phone.should eq('6969')
    end
    it 'adds the user phone if one exists and creation org has no phone' do 
      bike = Bike.new
      b_param = BParam.new
      user = User.new
      bike.stub(:creation_organization).and_return(nil)
      user.stub(:phone).and_return('69')
      bike.stub(:creator).and_return(user)
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.add_phone
      bike.phone.should eq('69')
    end
    it "does not raise an error if it can't find a phone" do 
      bike = Bike.new
      b_param = BParam.new
      user = User.new
      organization = Organization.new
      bike.stub(:creation_organization).and_return(organization)
      bike.stub(:creator).and_return(user)
      user.stub(:phone).and_return(nil)
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.add_phone.should be_nil
    end
  end

  describe :check_example do 
    it 'makes the bike an example if it was created by example organization' do 
      org = FactoryGirl.create(:organization, name: 'Example organization')
      bike = Bike.new
      b_param = BParam.new
      bike.stub(:creation_organization_id).and_return(org.id)
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.check_example
      bike.example.should be_true
    end
    it 'does not make the bike an example' do 
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.check_example
      bike.example.should be_false
    end
  end

  describe :stolenize do 
    it 'calls add_phone and marks the bike stolen' do 
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:add_phone).and_return(true)
      creator.stolenize
      bike.stolen.should be_true
    end
  end

  describe :recoverize do 
    it 'marks the bike recovered and stolen' do 
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:stolenize).and_return(true)
      creator.recoverize
      bike.recovered.should be_true
    end
  end

  describe :check_token do
    it 'sets the bike to what BikeCreatorTokenizer returns' do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorVerifier.new(b_param, bike)
      BikeCreatorTokenizer.any_instance.should_receive(:tokenized_bike).and_return(bike)
      creator.check_token.should eq(bike)
    end
  end

  describe :check_organization do
    it 'sets the bike to what BikeCreatorTokenizer returns' do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorVerifier.new(b_param, bike)
      BikeCreatorOrganizer.any_instance.should_receive(:organized_bike).and_return(bike)
      creator.check_organization.should eq(bike)
    end
  end

  describe :check_stolen_and_recovered do 
    it "returns false if the bike isn't stolen or recovered" do
      bike = Bike.new
      b_param = BParam.new(params: {stolen: false})
      creator = BikeCreatorVerifier.new(b_param, bike).check_stolen_and_recovered
      creator.should be_false
    end
    it 'calls stolenize if there is a stolen attribute included' do
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:params).and_return(bike: {stolen: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:stolenize).and_return(true)
      creator.check_stolen_and_recovered
    end
    it 'calls stolenize if the stolen parameter is passed' do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:stolenize).and_return(true)
      creator.check_stolen_and_recovered
    end

    it 'calls recoverize if there is a recovered attribute included' do
      bike = Bike.new
      b_param = BParam.new
      b_param.stub(:params).and_return(bike: {recovered: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:recoverize).and_return(true)
      creator.check_stolen_and_recovered
    end
    it 'calls recoverize if the recovered parameter is passed' do 
      bike = Bike.new
      b_param = BParam.new(params: {recovered: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:recoverize).and_return(true)
      creator.check_stolen_and_recovered
    end
  end

  describe :verify do
    it 'calls the methods it needs to call' do 
      bike = Bike.new
      b_param = BParam.new(params: {stolen: true})
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.should_receive(:check_token).and_return(true) 
      creator.should_receive(:check_stolen_and_recovered).and_return(true)
      creator.should_receive(:check_example).and_return(true)
      creator.verify.should eq(bike)
    end
  end


end
