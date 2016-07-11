require 'spec_helper'

describe BikeCreatorVerifier do
  describe 'add_phone' do
    it 'calls add the org phone if one exists' do
      bike = Bike.new
      organization = Organization.new
      location = Location.new
      b_param = BParam.new
      allow(organization).to receive(:locations).and_return([location])
      allow(location).to receive(:phone).and_return('6969')
      allow(bike).to receive(:creation_organization).and_return(organization)
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.add_phone
      expect(bike.phone).to eq('6969')
    end
    it 'adds the user phone if one exists and creation org has no phone' do
      bike = Bike.new
      b_param = BParam.new
      user = User.new
      allow(bike).to receive(:creation_organization).and_return(nil)
      allow(user).to receive(:phone).and_return('69')
      allow(bike).to receive(:creator).and_return(user)
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.add_phone
      expect(bike.phone).to eq('69')
    end
    it "does not raise an error if it can't find a phone" do
      bike = Bike.new
      b_param = BParam.new
      user = User.new
      organization = Organization.new
      allow(bike).to receive(:creation_organization).and_return(organization)
      allow(bike).to receive(:creator).and_return(user)
      allow(user).to receive(:phone).and_return(nil)
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator.add_phone).to be_nil
    end
  end

  describe 'check_example' do
    it 'makes the bike an example if it was created by example organization' do
      org = FactoryGirl.create(:organization, name: 'Example organization')
      bike = Bike.new
      b_param = BParam.new
      allow(bike).to receive(:creation_organization_id).and_return(org.id)
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.check_example
      expect(bike.example).to be_truthy
    end
    it 'does not make the bike an example' do
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorVerifier.new(b_param, bike)
      creator.check_example
      expect(bike.example).to be_falsey
    end
  end

  describe 'stolenize' do
    it 'calls add_phone and marks the bike stolen' do
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator).to receive(:add_phone).and_return(true)
      creator.stolenize
      expect(bike.stolen).to be_truthy
    end
  end

  describe 'recoverize' do
    it 'marks the bike recovered and stolen' do
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator).to receive(:stolenize).and_return(true)
      creator.recoverize
      expect(bike.recovered).to be_truthy
    end
  end

  describe 'check_organization' do
    it 'sets the bike to what BikeCreatorOrganizer returns' do
      bike = Bike.new
      b_param = BParam.new(params: { stolen: false })
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect_any_instance_of(BikeCreatorOrganizer).to receive(:organized_bike).and_return(bike)
      expect(creator.check_organization).to eq(bike)
    end
  end

  describe 'check_stolen_and_recovered' do
    it "returns false if the bike isn't stolen or recovered" do
      bike = Bike.new
      b_param = BParam.new(params: { stolen: false })
      creator = BikeCreatorVerifier.new(b_param, bike).check_stolen_and_recovered
      expect(creator).to be_falsey
    end
    it 'calls stolenize if there is a stolen attribute included' do
      bike = Bike.new
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return({ bike: { stolen: true } }.as_json)
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator).to receive(:stolenize).and_return(true)
      creator.check_stolen_and_recovered
    end
    it 'calls stolenize if the stolen parameter is passed' do
      bike = Bike.new
      b_param = BParam.new(params: { stolen: true })
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator).to receive(:stolenize).and_return(true)
      creator.check_stolen_and_recovered
    end

    it 'calls recoverize if there is a recovered attribute included' do
      bike = Bike.new
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return({ bike: { recovered: true } }.as_json)
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator).to receive(:recoverize).and_return(true)
      creator.check_stolen_and_recovered
    end
    it 'calls recoverize if the recovered parameter is passed' do
      bike = Bike.new
      b_param = BParam.new(params: { recovered: true })
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator).to receive(:recoverize).and_return(true)
      creator.check_stolen_and_recovered
    end
  end

  describe 'verify' do
    it 'calls the methods it needs to call' do
      bike = Bike.new
      b_param = BParam.new(params: { stolen: true })
      creator = BikeCreatorVerifier.new(b_param, bike)
      expect(creator).to receive(:check_stolen_and_recovered).and_return(true)
      expect(creator).to receive(:check_example).and_return(true)
      expect(creator.verify).to eq(bike)
    end
  end
end
