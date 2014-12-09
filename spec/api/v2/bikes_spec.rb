require 'spec_helper'

describe 'Bikes API V2' do
  describe 'bike search' do
    it "returns one with from an id" do
      create_doorkeeper_app
      bike = FactoryGirl.create(:bike)
      FactoryGirl.create(:bike)
      get '/api/v2/bikes?per_page=1', :format => :json, :access_token => @token.token
      response.code.should == '200'
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to eq(bike.id)
    end

    it "responds with 401" do 
      create_doorkeeper_app
      get "/api/v2/bikes/10"
      response.code.should == '401'
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