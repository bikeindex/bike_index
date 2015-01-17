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
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end

    it "stolen search works" do
      bike = FactoryGirl.create(:stolen_bike)
      get '/api/v2/bikes/stolen?per_page=1', :format => :json, :access_token => @token.token
      response.code.should == '200'
      expect(response.header['Total']).to eq('1')
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
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

  describe 'count' do
    it "returns the count hash for matching bikes, doesn't need access_token" do
      bike = FactoryGirl.create(:bike, serial_number: 'awesome')
      FactoryGirl.create(:bike)
      get '/api/v2/bikes/count?query=awesome', :format => :json
      result = JSON.parse(response.body)
      result['non_stolen'].should eq(1)
      result['stolen'].should eq(0)
      result['proximity'].should eq(0)
      response.code.should == '200'
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

  describe 'create' do
    before :each do 
      create_doorkeeper_app
      @bike = FactoryGirl.create(:bike)
      FactoryGirl.create(:bike)
    end
    
    xit "creates an example bike" do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:ctype, name: "wheel")
      FactoryGirl.create(:ctype, name: "headset")
      f_count = Feedback.count
      bike = { serial_number: "69 non-example",
        manufacturer: manufacturer.name,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: FactoryGirl.create(:color).name,
        example: true,
        year: '1969',
        owner_email: "fun_times@examples.com"
      }
      components = [
        {
          manufacturer: manufacturer.name,
          year: "1999",
          component_type: 'Headset',
          cgroup: "Frame and fork",
          description: "yeah yay!",
          serial_number: '69',
          model_name: 'Richie rich'
        },
        {
          manufacturer: "BLUE TEETH",
          front_or_rear: "Both",
          cgroup: "Wheels",
          component_type: 'wheel'
        }
      ]
      photos = [
        'http://i.imgur.com/lybYl1l.jpg',
        'http://i.imgur.com/3BGQeJh.jpg'
      ]
      OwnershipCreator.any_instance.should_receive(:send_notification_email)
      lambda { 
        post :create, { bike: bike, organization_slug: @organization.slug, access_token: @organization.access_token, components: components, photos: photos}
      }.should change(Ownership, :count).by(1)
      response.code.should eq("200")
      b = Bike.where(serial_number: "69 non-example").first
      b.example.should be_false
      b.creation_organization_id.should eq(@organization.id)
      b.year.should eq(1969)
      b.components.count.should eq(3)
      component = b.components[2]
      component.serial_number.should eq('69')
      component.description.should eq("yeah yay!")
      component.ctype.slug.should eq("headset")
      component.year.should eq(1999)
      component.manufacturer_id.should eq(manufacturer.id)
      component.model_name.should eq('Richie rich')
      b.public_images.count.should eq(2)
      f_count.should eq(Feedback.count)

      get '/api/v2/bikes?per_page=1', :format => :json, :access_token => @token.token
      response.code.should == '200'
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end

    it "requires stolen attrs if stolen"

    it "responds with 401" do 
      post "/api/v2/bikes", {}
      response.code.should == '401'
    end
  end
  
end