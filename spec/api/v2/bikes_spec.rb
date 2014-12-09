require 'spec_helper'

describe 'Bikes API V2' do
  describe 'bike search' do
    before :each do 
      create_doorkeeper_app
      @bike = FactoryGirl.create(:bike)
      FactoryGirl.create(:bike)
    end
    it "all bikes (root) search works" do
      get '/api/v2/bikes?per_page=1', :format => :json, :access_token => @token.token
      response.code.should == '200'
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end

    it "non_stolen bikes search works" do
      get '/api/v2/bikes/non_stolen?per_page=1', :format => :json, :access_token => @token.token
      response.code.should == '200'
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to eq(@bike.id)
    end

    it "stolen search works" do
      bike = FactoryGirl.create(:stolen_bike)
      get '/api/v2/bikes/stolen?per_page=1', :format => :json, :access_token => @token.token
      response.code.should == '200'
      expect(response.header['Total']).to eq('1')
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to eq(bike.id)
    end

    it "responds with 401" do 
      get "/api/v2/bikes/10"
      response.code.should == '401'
    end
  end

  describe 'fuzzy serial search' do
    xit "returns one with from an id " do
      # This fails because of levenshtein being gone most of the time. No biggie
      create_doorkeeper_app
      # bike = FactoryGirl.create(:bike, serial_number: 'Something1')
      # get "/api/v2/bikes", :format => :json
      get "/api/v2/bikes/close_serials?serial=s0meth1ngl", :format => :json, :access_token => @token.token
      result = response.body
      response.code.should == '200'
      expect(response.header['Total']).to eq('1')
      expect(JSON.parse(result)['bike']['id']).to eq(bike.id)
    end
  end

  describe 'find by id' do
    before :all do
      create_doorkeeper_app
    end
    it "returns one with from an id" do
      bike = FactoryGirl.create(:bike)
      get "/api/v2/bikes/#{bike.id}", :format => :json, :access_token => @token.token
      result = response.body
      response.code.should == '200'
      expect(JSON.parse(result)['bike']['id']).to eq(bike.id)
    end

    it "responds with missing" do 
      token = Doorkeeper::AccessToken.create!(application_id: @application.id, resource_owner_id: @user.id)
      get "/api/v2/bikes/10", :format => :json, :access_token => token.token
      response.code.should == '404'
      expect(JSON(response.body)["message"].present?).to be_true
    end
  end
  
end