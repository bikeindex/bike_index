require 'spec_helper'

describe 'Bikes API V2' do
  describe 'bike search' do
    before :each do 
      @bike = FactoryGirl.create(:bike)
      FactoryGirl.create(:bike)
    end
    it "all bikes (root) search works" do
      get '/api/v2/bikes_search?per_page=1', :format => :json
      response.code.should == '200'
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end

    it "non_stolen bikes search works" do
      get '/api/v2/bikes_search/non_stolen?per_page=1', :format => :json
      response.code.should == '200'
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end

    it "serial search works" do 
      bike = FactoryGirl.create(:bike, serial_number: '0000HEYBB')
      get "/api/v2/bikes_search/?serial=0HEYBB", :format => :json
      result = JSON.parse(response.body)
      response.code.should == '200'
      expect(response.header['Total']).to eq('1')
      expect(result['bikes'][0]['id']).to eq(bike.id)
    end

    it "stolen search works" do
      bike = FactoryGirl.create(:stolen_bike)
      get '/api/v2/bikes_search/stolen?per_page=1', :format => :json
      response.code.should == '200'
      expect(response.header['Total']).to eq('1')
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end
  end

  describe 'fuzzy serial search' do
    it "finds a close one" do
      bike = FactoryGirl.create(:bike, serial_number: 'Something1')
      bike.create_normalized_serial_segments
      get "/api/v2/bikes_search/close_serials?serial=s0meth1nglvv", :format => :json
      result = JSON.parse(response.body)
      response.code.should == '200'
      expect(response.header['Total']).to eq('1')
      expect(result['bikes'][0]['id']).to eq(bike.id)
    end
  end

  describe 'count' do
    it "returns the count hash for matching bikes, doesn't need access_token" do
      bike = FactoryGirl.create(:bike, serial_number: 'awesome')
      FactoryGirl.create(:bike)
      get '/api/v2/bikes_search/count?query=awesome', :format => :json
      result = JSON.parse(response.body)
      result['non_stolen'].should eq(1)
      result['stolen'].should eq(0)
      result['proximity'].should eq(0)
      response.code.should == '200'
    end
  end
end