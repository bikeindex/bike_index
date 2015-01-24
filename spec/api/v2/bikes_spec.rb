require 'spec_helper'

describe 'Bikes API V2' do
  

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

  describe 'create' do
    before :each do 
      create_doorkeeper_app({scopes: 'read_bikes write_bikes'})
      manufacturer = FactoryGirl.create(:manufacturer)
      color = FactoryGirl.create(:color)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      @bike = { serial: "69 non-example",
        manufacturer: manufacturer.name,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: color.name,
        year: '1969',
        owner_email: "fun_times@examples.com"
      }
    end

    it "responds with 401" do 
      post "/api/v2/bikes", @bike.to_json
      response.code.should == '401'
    end

    it "fails if the token doesn't have write_bikes scope" do 
      @token.update_attribute :scopes, 'read_bikes'
      post "/api/v2/bikes?access_token=#{@token.token}", @bike.to_json, { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      response.code.should eq('403')
    end

    it "creates a non example bike" do 
      expect{
        post "/api/v2/bikes?access_token=#{@token.token}",
          @bike.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      response.code.should eq("201")
      result = JSON.parse(response.body)['bike']
      result['serial'].should eq(@bike[:serial])
      result['manufacturer_name'].should eq(@bike[:manufacturer])
      Bike.find(result['id']).example.should be_false
    end

    it "creates an example bike" do
      FactoryGirl.create(:organization, name: "Example organization")
      expect{
        post "/api/v2/bikes?access_token=#{@token.token}",
          @bike.merge(test: true).to_json,
          { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
      response.code.should eq("201")
      result = JSON.parse(response.body)['bike']
      result['serial'].should eq(@bike[:serial])
      result['manufacturer_name'].should eq(@bike[:manufacturer])
      Bike.unscoped.find(result['id']).example.should be_true
    end

    it "fails to create a bike if the user isn't a member of the organization" do
      org = FactoryGirl.create(:organization, name: "Something")
      bike = @bike.merge(organization_slug: org.slug)
      post "/api/v2/bikes?access_token=#{@token.token}",
        bike.to_json,
        { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      response.code.should eq("401")
    end

    it "creates a bike through an organization" do 
      organization = FactoryGirl.create(:organization)
      FactoryGirl.create(:membership, user: @user, organization: organization)
      organization.save
      bike = @bike.merge(organization_slug: organization.slug)
      expect{
        post "/api/v2/bikes?access_token=#{@token.token}", 
          bike.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      result = JSON.parse(response.body)['bike']
      result['serial'].should eq(@bike[:serial])
      result['manufacturer_name'].should eq(@bike[:manufacturer])
      Bike.find(result['id']).creation_organization.should eq(organization)
    end

    it "requires stolen attrs if stolen"
  end

  

  describe :send_stolen_notification do 
    it "fails to send a stolen notification without read_user" do
      create_doorkeeper_app
      bike = FactoryGirl.create(:stolen_bike)
      params = {message: "Something I'm sending you"}
      post "/api/v2/bikes/#{bike.id}/send_stolen_notification?access_token=#{@token.token}",
        params.to_json,
        { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      response.code.should eq('403')
    end

    it "fails if the bike isn't stolen" do 
      create_doorkeeper_app({scopes: 'read_user'})
      bike = FactoryGirl.create(:bike)
      params = {message: "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod \ntempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, \nquis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo \nconsequat. Duis aute irure dolor in reprehenderit in voluptate velit esse \ncillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non \nproident, sunt in culpa qui officia deserunt mollit anim id est laborum."}
      post "/api/v2/bikes/#{bike.id}/send_stolen_notification?access_token=#{@token.token}",
        params.to_json,
        { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      pp response.body
      response.code.should eq('401')
    end

    xit "fails if the bike isn't owned by the access token user" do
      create_doorkeeper_app({scopes: 'read_user'})
      bike = FactoryGirl.create(:bike)
      params = {message: "Something I'm sending you"}
      post "/api/v2/bikes/#{bike.id}/send_stolen_notification?access_token=#{@token.token}",
        params.to_json,
        { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      pp response.body
      response.code.should eq('401')
    end

    xit "sends a notification" do 
      create_doorkeeper_app({scopes: 'read_user'})
      bike = FactoryGirl.create(:stolen_bike, owner_email: @user.id)
      params = {message: "Something I'm sending you"}
      expect{
        post "/api/v2/bikes/#{bike.id}/send_stolen_notification?access_token=#{@token.token}",
          params.to_json,
          { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      response.code.should eq('201')
    end
  end
  
end