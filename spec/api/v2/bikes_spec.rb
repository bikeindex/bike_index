require 'spec_helper'

describe 'Bikes API V2' do
  JSON_CONTENT = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }.freeze

  describe 'find by id' do
    it 'returns one with from an id' do
      bike = FactoryGirl.create(:bike)
      get "/api/v2/bikes/#{bike.id}", format: :json
      result = JSON.parse(response.body)
      expect(response.code).to eq('200')
      expect(result['bike']['id']).to eq(bike.id)
      expect(response.headers['Content-Type'].match('json')).to be_present
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(response.headers['Access-Control-Request-Method']).to eq('*')
    end

    it 'responds with missing' do
      get '/api/v2/bikes/10', format: :json
      result = JSON(response.body)
      expect(response.code).to eq('404')
      expect(result['error'].present?).to be_truthy
      expect(response.headers['Content-Type'].match('json')).to be_present
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(response.headers['Access-Control-Request-Method']).to eq('*')
    end
  end

  describe 'create' do
    before :each do
      create_doorkeeper_app(scopes: 'read_bikes write_bikes')
      manufacturer = FactoryGirl.create(:manufacturer)
      color = FactoryGirl.create(:color)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: 'bike')
      FactoryGirl.create(:propulsion_type, name: 'Foot pedal')
      @bike = { serial: '69 non-example',
                manufacturer: manufacturer.name,
                rear_tire_narrow: 'true',
                rear_wheel_bsd: '559',
                color: color.name,
                year: '1969',
                owner_email: 'fun_times@examples.com'
      }
    end

    it 'responds with 401' do
      post '/api/v2/bikes', @bike.to_json
      expect(response.code).to eq('401')
    end

    it "fails if the token doesn't have write_bikes scope" do
      @token.update_attribute :scopes, 'read_bikes'
      post "/api/v2/bikes?access_token=#{@token.token}", @bike.to_json, JSON_CONTENT
      expect(response.code).to eq('403')
    end

    it 'creates a non example bike, with components' do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:ctype, name: 'wheel')
      FactoryGirl.create(:ctype, name: 'Headset')
      front_gear_type = FactoryGirl.create(:front_gear_type)
      handlebar_type = FactoryGirl.create(:handlebar_type)
      components = [
        {
          manufacturer: manufacturer.name,
          year: '1999',
          component_type: 'headset',
          description: 'yeah yay!',
          serial_number: '69',
          model_name: 'Richie rich'
        },
        {
          manufacturer: 'BLUE TEETH',
          front_or_rear: 'Both',
          component_type: 'wheel'
        }
      ]
      @bike.merge!(components: components,
                   front_gear_type_slug: front_gear_type.slug,
                   handlebar_type_slug: handlebar_type.slug,
                   is_for_sale: true)
      expect do
        post "/api/v2/bikes?access_token=#{@token.token}",
             @bike.to_json,
             JSON_CONTENT
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      expect(response.code).to eq('201')
      result = JSON.parse(response.body)['bike']
      expect(result['serial']).to eq(@bike[:serial])
      expect(result['manufacturer_name']).to eq(@bike[:manufacturer])
      bike = Bike.find(result['id'])
      expect(bike.example).to be_falsey
      expect(bike.is_for_sale).to be_truthy
      expect(bike.components.count).to eq(3)
      expect(bike.components.pluck(:manufacturer_id).include?(manufacturer.id)).to be_truthy
      expect(bike.components.pluck(:ctype_id).uniq.count).to eq(2)
      expect(bike.front_gear_type).to eq(front_gear_type)
      expect(bike.handlebar_type).to eq(handlebar_type)
    end

    it "doesn't send an email" do
      expect do
        post "/api/v2/bikes?access_token=#{@token.token}",
             @bike.merge(no_notify: true).to_json,
             JSON_CONTENT
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
      expect(response.code).to eq('201')
    end

    it 'creates an example bike' do
      FactoryGirl.create(:organization, name: 'Example organization')
      expect do
        post "/api/v2/bikes?access_token=#{@token.token}",
             @bike.merge(test: true).to_json,
             JSON_CONTENT
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
      expect(response.code).to eq('201')
      result = JSON.parse(response.body)['bike']
      expect(result['serial']).to eq(@bike[:serial])
      expect(result['manufacturer_name']).to eq(@bike[:manufacturer])
      bike = Bike.unscoped.find(result['id'])
      expect(bike.example).to be_truthy
      expect(bike.is_for_sale).to be_falsey
    end

    it "fails to create a bike if the user isn't a member of the organization" do
      org = FactoryGirl.create(:organization, name: 'Something')
      bike = @bike.merge(organization_slug: org.slug)
      post "/api/v2/bikes?access_token=#{@token.token}",
           bike.to_json,
           JSON_CONTENT
      expect(response.code).to eq('401')
      result = JSON.parse(response.body)
      expect(result['error'].is_a?(String)).to be_truthy
    end

    it 'creates a stolen bike through an organization and uses the passed phone' do
      organization = FactoryGirl.create(:organization)
      @user.update_attribute :phone, '0987654321'
      FactoryGirl.create(:membership, user: @user, organization: organization)
      FactoryGirl.create(:country, iso: 'US')
      FactoryGirl.create(:state, abbreviation: 'Palace')
      organization.save
      bike = @bike.merge(organization_slug: organization.slug)
      date_stolen = 1357192800
      bike[:stolen_record] = {
        phone: '1234567890',
        date_stolen: date_stolen,
        theft_description: "This bike was stolen and that's no fair.",
        country: 'US',
        city: 'Chicago',
        street: 'Cortland and Ashland',
        zipcode: '60622',
        state: 'Palace',
        police_report_number: '99999999',
        police_report_department: 'Chicago',
        # locking_description: 'some locking description',
        # lock_defeat_description: 'broken in some crazy way'
      }
      expect do
        post "/api/v2/bikes?access_token=#{@token.token}",
             bike.to_json,
             JSON_CONTENT
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      result = JSON.parse(response.body)['bike']
      expect(result['serial']).to eq(@bike[:serial])
      expect(result['manufacturer_name']).to eq(@bike[:manufacturer])
      expect(result['stolen_record']['date_stolen']).to eq(date_stolen)
      b = Bike.find(result['id'])
      expect(b.creation_organization).to eq(organization)
      expect(b.stolen).to be_truthy
      expect(b.current_stolen_record_id).to be_present
      expect(b.current_stolen_record.police_report_number).to eq(bike[:stolen_record][:police_report_number])
      expect(b.current_stolen_record.phone).to eq('1234567890')
    end

    it 'does not register a stolen bike unless attrs are present' do
    end
  end

  describe 'create v2_accessor' do
    before :each do
      create_doorkeeper_app(with_v2_accessor: true)
      manufacturer = FactoryGirl.create(:manufacturer)
      color = FactoryGirl.create(:color)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: 'bike')
      FactoryGirl.create(:propulsion_type, name: 'Foot pedal')
      @organization = FactoryGirl.create(:organization)
      @bike = { serial: '69 non-example',
                manufacturer: manufacturer.name,
                rear_tire_narrow: 'true',
                rear_wheel_bsd: '559',
                color: color.name,
                year: '1969',
                owner_email: 'fun_times@examples.com',
                organization_slug: @organization.slug
      }
    end

    it 'creates a bike for organization with v2_accessor' do
      FactoryGirl.create(:membership, user: @user, organization: @organization, role: 'admin')
      @organization.save
      post "/api/v2/bikes?access_token=#{@accessor_token.token}",
           @bike.to_json,
           JSON_CONTENT
      result = JSON.parse(response.body)['bike']
      expect(response.code).to eq('201')
      b = Bike.find(result['id'])
      expect(b.creation_organization).to eq(@organization)
      expect(b.creator).to eq(@user)
    end

    it "doesn't create a bike without an organization with v2_accessor" do
      FactoryGirl.create(:membership, user: @user, organization: @organization, role: 'admin')
      @organization.save
      @bike.delete(:organization_slug)
      post "/api/v2/bikes?access_token=#{@accessor_token.token}",
           @bike.to_json,
           JSON_CONTENT
      result = JSON.parse(response.body)

      expect(response.code).to eq('403')
      result = JSON.parse(response.body)
      expect(result['error'].is_a?(String)).to be_truthy
    end

    it "fails to create a bike if the app owner isn't a member of the organization" do
      expect(@user.has_membership?).to be_falsey
      post "/api/v2/bikes?access_token=#{@accessor_token.token}",
           @bike.to_json,
           JSON_CONTENT
      result = JSON.parse(response.body)
      expect(response.code).to eq('403')
      result = JSON.parse(response.body)
      expect(result['error'].is_a?(String)).to be_truthy
    end
  end

  describe 'update' do
    before :each do
      create_doorkeeper_app(scopes: 'read_user write_bikes')
      @bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      @params = {
        year: 1999,
        serial_number: 'XXX69XXX'
      }
      @url = "/api/v2/bikes/#{@bike.id}?access_token=#{@token.token}"
    end

    it "doesn't update if user doesn't own the bike" do
      @bike.current_ownership.update_attributes(user_id: FactoryGirl.create(:user).id, claimed: true)
      expect_any_instance_of(Bike).to receive(:type).and_return('unicorn')
      put @url, @params.to_json, JSON_CONTENT
      expect(response.body.match('do not own that unicorn')).to be_present
      expect(response.code).to eq('403')
    end

    it "doesn't update if not in scope" do
      @token.update_attribute :scopes, 'public'
      put @url, @params.to_json, JSON_CONTENT
      expect(response.code).to eq('403')
      expect(response.body).to match(/oauth/i)
      expect(response.body).to match(/permission/i)
    end

    it "fails to update bike if required stolen attrs aren't present" do
      FactoryGirl.create(:country, iso: 'US')
      expect(@bike.year).to be_nil
      serial = @bike.serial_number
      @params[:stolen_record] = {
        phone: '',
        city: 'Chicago'
      }
      put @url, @params.to_json, JSON_CONTENT
      expect(response.code).to eq('401')
      expect(response.body.match('missing phone')).to be_present
    end

    it "updates a bike, adds a stolen record, doesn't update locked attrs" do
      FactoryGirl.create(:country, iso: 'US')
      expect(@bike.year).to be_nil
      serial = @bike.serial_number
      @params[:stolen_record] = {
        city: 'Chicago',
        phone: '1234567890',
        police_report_number: '999999'
      }
      @params[:owner_email] = 'foo@new_owner.com'
      expect do
        put @url, @params.to_json, JSON_CONTENT
      end.to change(Ownership, :count).by(1)
      expect(response.code).to eq('200')
      expect(@bike.reload.year).to eq(@params[:year])
      expect(@bike.serial_number).to eq(serial)
      expect(@bike.stolen).to be_truthy
      expect(@bike.current_stolen_record.date_stolen.to_i).to be > Time.now.to_i - 10
      expect(@bike.current_stolen_record.police_report_number).to eq('999999')
    end

    it 'updates a bike, adds and removes components' do
      # FactoryGirl.create(:manufacturer, name: 'Other')
      manufacturer = FactoryGirl.create(:manufacturer)
      wheels = FactoryGirl.create(:ctype, name: 'wheel')
      headsets = FactoryGirl.create(:ctype, name: 'Headset')
      comp = FactoryGirl.create(:component, bike: @bike, ctype: headsets)
      comp2 = FactoryGirl.create(:component, bike: @bike, ctype: wheels)
      not_urs = FactoryGirl.create(:component)
      # pp comp2
      @bike.reload
      expect(@bike.components.count).to eq(2)
      components = [
        {
          manufacturer: manufacturer.name,
          year: '1999',
          component_type: 'headset',
          description: 'Second component',
          serial_number: '69',
          model_name: 'Richie rich'
        }, {
          manufacturer: 'BLUE TEETH',
          front_or_rear: 'Rear',
          description: 'third component'
        }, {
          id: comp.id,
          destroy: true
        }, {
          id: comp2.id,
          year: '1999',
          description: 'First component'
        }
      ]
      @params[:is_for_sale] = true
      @params[:components] = components
      expect do
        put @url, @params.to_json, JSON_CONTENT
      end.to change(Ownership, :count).by(0)
      # pp response.body
      expect(response.code).to eq('200')
      @bike.reload
      @bike.components.reload
      expect(@bike.is_for_sale).to be_truthy
      expect(@bike.year).to eq(@params[:year])
      expect(comp2.reload.year).to eq(1999)
      expect(@bike.components.pluck(:manufacturer_id).include?(manufacturer.id)).to be_truthy
      expect(@bike.components.count).to eq(3)
    end

    it "doesn't remove components that aren't the bikes" do
      manufacturer = FactoryGirl.create(:manufacturer)
      comp = FactoryGirl.create(:component, bike: @bike)
      not_urs = FactoryGirl.create(:component)
      components = [
        {
          id: comp.id,
          year: 1999
        }, {
          id: not_urs.id,
          destroy: true
        }
      ]
      @params[:components] = components
      put @url, @params.to_json, JSON_CONTENT
      expect(response.code).to eq('401')
      expect(response.headers['Content-Type'].match('json')).to be_present
      # response.headers['Access-Control-Allow-Origin'].should eq('*')
      # response.headers['Access-Control-Request-Method'].should eq('*')
      expect(@bike.reload.components.reload.count).to eq(1)
      expect(@bike.components.pluck(:year).first).to eq(1999) # Feature, not a bug?
      expect(not_urs.reload.id).to be_present
    end

    it 'claims a bike and updates if it should' do
      expect(@bike.year).to be_nil
      @bike.current_ownership.update_attributes(owner_email: @user.email, creator_id: FactoryGirl.create(:user).id, claimed: false)
      expect(@bike.reload.owner).not_to eq(@user)
      put @url, @params.to_json, JSON_CONTENT
      expect(response.code).to eq('200')
      expect(response.headers['Content-Type'].match('json')).to be_present
      expect(@bike.reload.current_ownership.claimed).to be_truthy
      expect(@bike.owner).to eq(@user)
      expect(@bike.year).to eq(@params[:year])
    end
  end

  describe 'image' do
    it "doesn't post an image to a bike if the bike isn't owned by the user" do
      create_doorkeeper_app(scopes: 'read_user write_bikes')
      bike = FactoryGirl.create(:ownership).bike
      file = File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg'))
      url = "/api/v2/bikes/#{bike.id}/image?access_token=#{@token.token}"
      expect(bike.public_images.count).to eq(0)
      post url, file: Rack::Test::UploadedFile.new(file)
      expect(response.code).to eq('403')
      expect(response.headers['Content-Type'].match('json')).to be_present
      expect(bike.reload.public_images.count).to eq(0)
    end

    it 'errors on non whitelisted extensions' do
      create_doorkeeper_app(scopes: 'read_user write_bikes')
      bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      file = File.open(File.join(Rails.root, 'spec', 'spec_helper.rb'))
      url = "/api/v2/bikes/#{bike.id}/image?access_token=#{@token.token}"
      expect(bike.public_images.count).to eq(0)
      post url, file: Rack::Test::UploadedFile.new(file)
      expect(response.body.match(/not allowed to upload .?.rb/i)).to be_present
      expect(response.code).to eq('401')
      expect(bike.reload.public_images.count).to eq(0)
    end

    it 'posts an image' do
      create_doorkeeper_app(scopes: 'read_user write_bikes')
      bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      file = File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg'))
      url = "/api/v2/bikes/#{bike.id}/image?access_token=#{@token.token}"
      expect(bike.public_images.count).to eq(0)
      post url, file: Rack::Test::UploadedFile.new(file)
      expect(response.code).to eq('201')
      expect(response.headers['Content-Type'].match('json')).to be_present
      expect(bike.reload.public_images.count).to eq(1)
    end
  end

  describe 'send_stolen_notification' do
    before :each do
      create_doorkeeper_app(scopes: 'read_user')
      @bike = FactoryGirl.create(:ownership, creator_id: @user.id).bike
      @bike.update_attribute :stolen, true
      @params = { message: "Something I'm sending you" }
      @url = "/api/v2/bikes/#{@bike.id}/send_stolen_notification?access_token=#{@token.token}"
    end

    it 'fails to send a stolen notification without read_user' do
      @token.update_attribute :scopes, 'public'
      post @url, @params.to_json, JSON_CONTENT
      expect(response.code).to eq('403')
      expect(response.body).to match('OAuth')
      expect(response.body).to match(/permission/i)
      expect(response.body).to_not match('is not stolen')
    end

    it "fails if the bike isn't stolen" do
      @bike.update_attribute :stolen, false
      post @url, @params.to_json, JSON_CONTENT
      expect(response.code).to eq('400')
      expect(response.body.match('is not stolen')).to be_present
    end

    it "fails if the bike isn't owned by the access token user" do
      @bike.current_ownership.update_attributes(user_id: FactoryGirl.create(:user).id, claimed: true)
      post @url, @params.to_json, JSON_CONTENT
      expect(response.code).to eq('403')
      expect(response.body.match('application is not approved')).to be_present
    end

    it 'sends a notification' do
      expect do
        post @url, @params.to_json, JSON_CONTENT
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      expect(response.code).to eq('201')
    end
  end
end
