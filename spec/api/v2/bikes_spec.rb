require 'spec_helper'

describe 'Bikes API V2' do
  JSON_CONTENT = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  

  describe 'find by id' do
    it "returns one with from an id" do
      bike = FactoryGirl.create(:bike)
      get "/api/v2/bikes/#{bike.id}", :format => :json
      result = JSON.parse(response.body)
      response.code.should == '200'
      expect(result['bike']['id']).to eq(bike.id)
      response.headers['Content-Type'].match('json').should be_present
      response.headers['Access-Control-Allow-Origin'].should eq('*')
      response.headers['Access-Control-Request-Method'].should eq('*')
    end

    it "responds with missing" do 
      get "/api/v2/bikes/10", :format => :json
      result = JSON(response.body)
      response.code.should == '404'
      expect(result["error"].present?).to be_true
      response.headers['Content-Type'].match('json').should be_present
      response.headers['Access-Control-Allow-Origin'].should eq('*')
      response.headers['Access-Control-Request-Method'].should eq('*')
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
      post "/api/v2/bikes?access_token=#{@token.token}", @bike.to_json, JSON_CONTENT
      response.code.should eq('403')
    end

    it "creates a non example bike, with components" do 
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:ctype, name: "wheel")
      FactoryGirl.create(:ctype, name: "Headset")
      front_gear_type = FactoryGirl.create(:front_gear_type)
      handlebar_type = FactoryGirl.create(:handlebar_type)
      components = [
        {
          manufacturer: manufacturer.name,
          year: "1999",
          component_type: 'headset',
          description: "yeah yay!",
          serial_number: '69',
          model_name: 'Richie rich'
        },
        {
          manufacturer: "BLUE TEETH",
          front_or_rear: "Both",
          component_type: 'wheel'
        }
      ]
      @bike.merge!({
        components: components,
        front_gear_type_slug: front_gear_type.slug,
        handlebar_type_slug: handlebar_type.slug,
        is_for_sale: true,
      })
      expect{
        post "/api/v2/bikes?access_token=#{@token.token}",
          @bike.to_json,
          JSON_CONTENT
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      response.code.should eq("201")
      result = JSON.parse(response.body)['bike']
      result['serial'].should eq(@bike[:serial])
      result['manufacturer_name'].should eq(@bike[:manufacturer])
      bike = Bike.find(result['id'])
      bike.example.should be_false
      bike.is_for_sale.should be_true
      bike.components.count.should eq(3)
      bike.components.pluck(:manufacturer_id).include?(manufacturer.id).should be_true
      bike.components.pluck(:ctype_id).uniq.count.should eq(2)
      bike.front_gear_type.should eq(front_gear_type)
      bike.handlebar_type.should eq(handlebar_type)
    end

    it "doesn't send an email" do
      expect{
        post "/api/v2/bikes?access_token=#{@token.token}",
          @bike.merge(no_notify: true).to_json,
          JSON_CONTENT
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
      response.code.should eq("201")
    end

    it "creates an example bike" do
      FactoryGirl.create(:organization, name: "Example organization")
      expect{
        post "/api/v2/bikes?access_token=#{@token.token}",
          @bike.merge(test: true).to_json,
          JSON_CONTENT
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
      response.code.should eq("201")
      result = JSON.parse(response.body)['bike']
      result['serial'].should eq(@bike[:serial])
      result['manufacturer_name'].should eq(@bike[:manufacturer])
      bike = Bike.unscoped.find(result['id'])
      bike.example.should be_true
      bike.is_for_sale.should be_false
    end

    it "fails to create a bike if the user isn't a member of the organization" do
      org = FactoryGirl.create(:organization, name: "Something")
      bike = @bike.merge(organization_slug: org.slug)
      post "/api/v2/bikes?access_token=#{@token.token}",
        bike.to_json,
        JSON_CONTENT
      response.code.should eq("401")
      result = JSON.parse(response.body)
      result['error'].kind_of?(String).should be_true
    end

    it "creates a stolen bike through an organization" do 
      organization = FactoryGirl.create(:organization)
      FactoryGirl.create(:membership, user: @user, organization: organization)
      FactoryGirl.create(:country, iso: "US")
      FactoryGirl.create(:state, abbreviation: "Palace")
      organization.save
      bike = @bike.merge(organization_slug: organization.slug)
      date_stolen = 1357192800
      bike[:stolen_record] = {
        phone: '1234567890',
        date_stolen: date_stolen,
        theft_description: "This bike was stolen and that's no fair.",
        country: "US",
        city: 'Chicago',
        street: "Cortland and Ashland",
        zipcode: "60622",
        state: "Palace",
        police_report_number: "99999999",
        police_report_department: "Chicago",
        # locking_description: 'some locking description',
        # lock_defeat_description: 'broken in some crazy way'
      }
      expect{
        post "/api/v2/bikes?access_token=#{@token.token}", 
          bike.to_json,
          JSON_CONTENT
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      result = JSON.parse(response.body)['bike']
      result['serial'].should eq(@bike[:serial])
      result['manufacturer_name'].should eq(@bike[:manufacturer])
      result['stolen_record']['date_stolen'].should eq(date_stolen)
      b = Bike.find(result['id'])
      b.creation_organization.should eq(organization)
      b.stolen.should be_true
      b.current_stolen_record_id.should be_present
      b.current_stolen_record.police_report_number.should eq(bike[:stolen_record][:police_report_number])
    end

    it "does not register a stolen bike unless attrs are present" do

    end
  end

  describe 'create v2_accessor' do 
    before :each do 
      create_doorkeeper_app({with_v2_accessor: true})
      manufacturer = FactoryGirl.create(:manufacturer)
      color = FactoryGirl.create(:color)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      @organization = FactoryGirl.create(:organization)
      @bike = { serial: "69 non-example",
        manufacturer: manufacturer.name,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: color.name,
        year: '1969',
        owner_email: "fun_times@examples.com",
        organization_slug: @organization.slug
      }
    end
    
    it "creates a bike for organization with v2_accessor" do
      FactoryGirl.create(:membership, user: @user, organization: @organization, role: 'admin')
      @organization.save
      post "/api/v2/bikes?access_token=#{@accessor_token.token}",
        @bike.to_json,
        JSON_CONTENT
      result = JSON.parse(response.body)['bike']
      response.code.should eq("201")
      b = Bike.find(result['id'])
      b.creation_organization.should eq(@organization)
      b.creator.should eq(@user)
    end

    it "doesn't create a bike without an organization with v2_accessor" do
      FactoryGirl.create(:membership, user: @user, organization: @organization, role: 'admin')
      @organization.save
      @bike.delete(:organization_slug)
      post "/api/v2/bikes?access_token=#{@accessor_token.token}",
        @bike.to_json,
        JSON_CONTENT
      result = JSON.parse(response.body)
      
      response.code.should eq("403")
      result = JSON.parse(response.body)
      result['error'].kind_of?(String).should be_true
    end

    it "fails to create a bike if the app owner isn't a member of the organization" do
      expect(@user.has_membership?).to be_false
      post "/api/v2/bikes?access_token=#{@accessor_token.token}",
        @bike.to_json,
        JSON_CONTENT
      result = JSON.parse(response.body)
      response.code.should eq("403")
      result = JSON.parse(response.body)
      result['error'].kind_of?(String).should be_true
    end
  end



  describe 'update' do
    before :each do 
      create_doorkeeper_app({scopes: 'read_user write_bikes'})
      @bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      @params = {
        year: 1999,
        serial_number: 'XXX69XXX'
      }
      @url = "/api/v2/bikes/#{@bike.id}?access_token=#{@token.token}"
    end

    it "doesn't update if user doesn't own the bike" do 
      @bike.current_ownership.update_attributes(user_id: FactoryGirl.create(:user).id, claimed: true)
      Bike.any_instance.should_receive(:type).and_return('unicorn')
      put @url, @params.to_json, JSON_CONTENT
      response.body.match('do not own that unicorn').should be_present
      response.code.should eq('403')
    end

    it "doesn't update if not in scope" do 
      @token.update_attribute :scopes, 'public'
      put @url, @params.to_json, JSON_CONTENT
      response.code.should eq('403') 
      response.body.match(/oauth/i).should be_present
      response.body.match(/permissions/i).should be_present
    end

    it "fails to update bike if required stolen attrs aren't present" do
      FactoryGirl.create(:country, iso: "US")
      @bike.year.should be_nil
      serial = @bike.serial_number
      @params[:stolen_record] = {
        phone: '',
        city: 'Chicago'
      }
      put @url, @params.to_json, JSON_CONTENT
      response.code.should eq('401')
      response.body.match('missing phone').should be_present
    end

    it "updates a bike, adds a stolen record, doesn't update locked attrs" do
      FactoryGirl.create(:country, iso: "US")
      @bike.year.should be_nil
      serial = @bike.serial_number
      @params[:stolen_record] = {
        city: 'Chicago',
        phone: '1234567890',
        police_report_number: "999999"
      }
      @params[:owner_email] = "foo@new_owner.com"
      lambda {
        put @url, @params.to_json, JSON_CONTENT
      }.should change(Ownership, :count).by(1)
      response.code.should eq('200')
      @bike.reload.year.should eq(@params[:year])
      @bike.serial_number.should eq(serial)
      @bike.stolen.should be_true
      @bike.current_stolen_record.date_stolen.to_i.should be > Time.now.to_i - 10
      @bike.current_stolen_record.police_report_number.should eq("999999")
    end

    it "updates a bike, adds and removes components" do
      # FactoryGirl.create(:manufacturer, name: 'Other')
      manufacturer = FactoryGirl.create(:manufacturer)
      wheels = FactoryGirl.create(:ctype, name: "wheel")
      headsets = FactoryGirl.create(:ctype, name: "Headset")
      comp = FactoryGirl.create(:component, bike: @bike, ctype: headsets)
      comp2 = FactoryGirl.create(:component, bike: @bike, ctype: wheels)
      not_urs = FactoryGirl.create(:component)
      # pp comp2
      @bike.reload
      @bike.components.count.should eq(2)
      components = [
        {
          manufacturer: manufacturer.name,
          year: "1999",
          component_type: 'headset',
          description: "Second component",
          serial_number: '69',
          model_name: 'Richie rich'
        },{
          manufacturer: "BLUE TEETH",
          front_or_rear: "Rear",
          description: 'third component'
        },{
          id: comp.id,
          destroy: true
        },{
          id: comp2.id,
          year: '1999',
          description: 'First component'
        }
      ]
      @params.merge!({is_for_sale: true, components: components})
      lambda {
        put @url, @params.to_json, JSON_CONTENT
      }.should change(Ownership, :count).by(0)
      # pp response.body
      response.code.should eq('200')
      @bike.reload
      @bike.components.reload
      @bike.is_for_sale.should be_true
      @bike.year.should eq(@params[:year])
      comp2.reload.year.should eq(1999)
      @bike.components.pluck(:manufacturer_id).include?(manufacturer.id).should be_true
      @bike.components.count.should eq(3)
    end

    it "doesn't remove components that aren't the bikes" do
      manufacturer = FactoryGirl.create(:manufacturer)
      comp = FactoryGirl.create(:component, bike: @bike)
      not_urs = FactoryGirl.create(:component)
      components = [
        {
          id: comp.id,
          year: 1999
        },{
          id: not_urs.id,
          destroy: true
        }
      ]
      @params.merge!({components: components})
      put @url, @params.to_json, JSON_CONTENT
      response.code.should eq('401')
      response.headers['Content-Type'].match('json').should be_present
      # response.headers['Access-Control-Allow-Origin'].should eq('*')
      # response.headers['Access-Control-Request-Method'].should eq('*')
      @bike.reload.components.reload.count.should eq(1)
      @bike.components.pluck(:year).first.should eq(1999) # Feature, not a bug?
      not_urs.reload.id.should be_present
    end

    it "claims a bike and updates if it should" do 
      @bike.year.should be_nil
      @bike.current_ownership.update_attributes(owner_email: @user.email, creator_id: FactoryGirl.create(:user).id, claimed: false)
      @bike.reload.owner.should_not eq(@user)
      put @url, @params.to_json, JSON_CONTENT
      response.code.should eq('200')
      response.headers['Content-Type'].match('json').should be_present
      @bike.reload.current_ownership.claimed.should be_true
      @bike.owner.should eq(@user)
      @bike.year.should eq(@params[:year])
    end
  end

  describe :image do 
    it "doesn't post an image to a bike if the bike isn't owned by the user" do 
      create_doorkeeper_app({scopes: 'read_user write_bikes'})
      bike = FactoryGirl.create(:ownership).bike
      file = File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg'))
      url = "/api/v2/bikes/#{bike.id}/image?access_token=#{@token.token}"
      bike.public_images.count.should eq(0)
      post url, {file: Rack::Test::UploadedFile.new(file)}
      response.code.should eq('403')
      response.headers['Content-Type'].match('json').should be_present
      bike.reload.public_images.count.should eq(0)
    end

    it "errors on non whitelisted extensions" do 
      create_doorkeeper_app({scopes: 'read_user write_bikes'})
      bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      file = File.open(File.join(Rails.root, 'spec', 'spec_helper.rb'))
      url = "/api/v2/bikes/#{bike.id}/image?access_token=#{@token.token}"
      bike.public_images.count.should eq(0)
      post url, {file: Rack::Test::UploadedFile.new(file)}
      response.body.match(/not allowed to upload .?.rb/i).should be_present
      response.code.should eq('401')
      bike.reload.public_images.count.should eq(0)
    end

    it "posts an image" do 
      create_doorkeeper_app({scopes: 'read_user write_bikes'})
      bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      file = File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg'))
      url = "/api/v2/bikes/#{bike.id}/image?access_token=#{@token.token}"
      bike.public_images.count.should eq(0)
      post url, {file: Rack::Test::UploadedFile.new(file)}
      response.code.should eq('201')
      response.headers['Content-Type'].match('json').should be_present
      bike.reload.public_images.count.should eq(1)
    end
  end

  describe :send_stolen_notification do 
    before :each do 
      create_doorkeeper_app({scopes: 'read_user'})
      @bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      @bike.update_attribute :stolen, true
      @params = {message: "Something I'm sending you"}
      @url = "/api/v2/bikes/#{@bike.id}/send_stolen_notification?access_token=#{@token.token}"
    end

    it "fails to send a stolen notification without read_user" do
      @token.update_attribute :scopes, 'public'
      post @url, @params.to_json, JSON_CONTENT
      response.code.should eq('403')
      response.body.match('OAuth').should be_present
      response.body.match('permissions').should be_present
      response.body.match('is not stolen').should_not be_present
    end

    it "fails if the bike isn't stolen" do 
      @bike.update_attribute :stolen, false
      post @url, @params.to_json, JSON_CONTENT
      response.code.should eq('400')
      response.body.match('is not stolen').should be_present
    end

    it "fails if the bike isn't owned by the access token user" do
      @bike.current_ownership.update_attributes(user_id: FactoryGirl.create(:user).id, claimed: true)
      post @url, @params.to_json, JSON_CONTENT
      response.code.should eq('403')
      response.body.match('application is not approved').should be_present
    end

    it "sends a notification" do 
      expect{
        post @url, @params.to_json, JSON_CONTENT
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      response.code.should eq('201')
    end
  end

end