require 'spec_helper'

describe Api::V1::BikesController do
  describe 'index' do
    it 'loads the page and have the correct headers' do
      FactoryGirl.create(:bike)
      get :index, format: :json
      expect(response.code).to eq('200')
    end
  end

  describe 'stolen_ids' do
    it 'returns correct code if no org' do
      c = FactoryGirl.create(:color)
      get :stolen_ids, format: :json
      expect(response.code).to eq('401')
    end

    xit 'should return an array of ids' do
      bike = FactoryGirl.create(:bike)
      stole1 = FactoryGirl.create(:stolen_record)
      stole2 = FactoryGirl.create(:stolen_record, approved: true)
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:membership, user: user, organization: organization)
      options = { stolen: true, organization_slug: organization.slug, access_token: organization.access_token }
      get :stolen_ids, options, format: :json
      expect(response.code).to eq('200')
      # pp response
      bikes = JSON.parse(response.body)
      expect(bikes.count).to eq(1)
      expect(bikes.first).to eq(stole2.bike.id)
    end
  end

  describe 'show' do
    it 'loads the page' do
      bike = FactoryGirl.create(:bike)
      get :show, id: bike.id, format: :json
      expect(response.code).to eq('200')
    end
  end

  describe 'create' do
    before do
      FactoryGirl.create(:cycle_type, slug: 'bike')
      FactoryGirl.create(:propulsion_type, name: 'Foot pedal')
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:ctype, name: 'wheel')
      FactoryGirl.create(:ctype, name: 'headset')
    end
    context 'pos_integrator rear_gear_type_slug error' do
      let(:auto_user) { FactoryGirl.create(:organization_auto_user) }
      let(:organization) { auto_user.organizations.first }
      let(:manufacturer) { FactoryGirl.create(:manufacturer, name: 'Specialized') }
      let(:black) { FactoryGirl.create(:color, name: 'Black') }
      let(:red) { FactoryGirl.create(:color, name: 'Red') }
      let(:bike_hash) do
        {
          organization_slug: organization.slug,
          access_token: organization.access_token,
          bike: {
            owner_email: 'example@gmail.com',
            serial_number: 'SSOMESERIAL',
            manufacturer: 'Specialized',
            frame_model: 'Diverge Elite DSW (58)',
            color: 'Black/Red',
            send_email: true,
            frame_size: '58',
            frame_size_unit: 'cm',
            year: 2016,
            rear_wheel_size: nil,
            rear_gear_type_slug: nil,
            handlebar_type_slug: nil,
            frame_material_slug: nil,
            description: 'Diverge Elite DSW (58)',
            registered_new: true
          }
        }
      end
      before do
        expect([black, red, manufacturer].size).to eq 3
      end
      it 'creates a bike' do
        expect do
          post :create, bike_hash.as_json, headers: { 'Content-Type' => 'application/json' }
        end.to change(Ownership, :count).by(1)
        expect(response.code).to eq('200')
        bike = Bike.where(serial_number: 'SSOMESERIAL').first
        expect(bike.manufacturer).to eq manufacturer
        expect(bike.frame_model).to eq 'Diverge Elite DSW (58)'
        expect(bike.frame_size).to eq '58cm'
        expect(bike.frame_size_unit).to eq 'cm'
        expect(bike.primary_frame_color).to eq black
        expect(bike.paint_description).to eq 'Black/Red'
      end
    end
    context 'legacy tests' do
      before :each do
        @organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        FactoryGirl.create(:membership, user: user, organization: @organization)
        @organization.save
      end

      it 'returns correct code if not logged in' do
        c = FactoryGirl.create(:color)
        post :create, { bike: { serial_number: '69', color: c.name } }
        expect(response.code).to eq('401')
      end

      it 'returns correct code if bike has errors' do
        c = FactoryGirl.create(:color)
        post :create, { bike: { serial_number: '69', color: c.name }, organization_slug: @organization.slug, access_token: @organization.access_token }
        expect(response.code).to eq('422')
      end

      it "emails us if it can't create a record" do
        c = FactoryGirl.create(:color)
        expect do
          post :create, { bike: { serial_number: '69', color: c.name }, organization_slug: @organization.slug, access_token: @organization.access_token }
        end.to change(Feedback, :count).by(1)
      end

      it 'creates a record and reset example' do
        manufacturer = FactoryGirl.create(:manufacturer)
        rear_gear_type = FactoryGirl.create(:rear_gear_type)
        front_gear_type = FactoryGirl.create(:front_gear_type)
        handlebar_type = FactoryGirl.create(:handlebar_type)
        f_count = Feedback.count
        bike_attrs = {
          serial_number: '69 non-example',
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: 'true',
          rear_wheel_bsd: 559,
          color: FactoryGirl.create(:color).name,
          example: true,
          year: '1969',
          owner_email: 'fun_times@examples.com',
          frame_model: "Tricruiser Tricycle",
          send_email: true,
          frame_size: '56cm',
          frame_size_unit: nil,
          rear_gear_type_slug: rear_gear_type.slug,
          front_gear_type_slug: front_gear_type.slug,
          handlebar_type_slug: handlebar_type.slug,
          registered_new: true
        }
        components = [
          {
            manufacturer: manufacturer.name,
            year: '1999',
            component_type: 'Headset',
            cgroup: 'Frame and fork',
            description: 'yeah yay!',
            serial_number: '69',
            model_name: 'Richie rich'
          },
          {
            manufacturer: 'BLUE TEETH',
            front_or_rear: 'Both',
            cgroup: 'Wheels',
            component_type: 'wheel'
          }
        ]
        photos = [
          'http://i.imgur.com/lybYl1l.jpg',
          'http://i.imgur.com/3BGQeJh.jpg'
        ]
        expect_any_instance_of(OwnershipCreator).to receive(:send_notification_email)
        expect do
          post :create, bike: bike_attrs, organization_slug: @organization.slug,
               access_token: @organization.access_token, components: components, photos: photos
        end.to change(Ownership, :count).by(1)
        expect(response.code).to eq('200')
        bike = Bike.where(serial_number: '69 non-example').first
        expect(bike.example).to be_falsey
        expect(bike.creation_organization_id).to eq(@organization.id)
        expect(bike.year).to eq(1969)
        expect(bike.components.count).to eq(3)
        component = bike.components[2]
        expect(component.serial_number).to eq('69')
        expect(component.description).to eq('yeah yay!')
        expect(component.ctype.slug).to eq('headset')
        expect(component.year).to eq(1999)
        expect(component.manufacturer_id).to eq(manufacturer.id)
        expect(component.cmodel_name).to eq('Richie rich')
        expect(bike.public_images.count).to eq(2)
        expect(f_count).to eq(Feedback.count)
        skipped = %w(send_email frame_size_unit rear_wheel_bsd color example rear_gear_type_slug front_gear_type_slug handlebar_type_slug)
        bike_attrs.except(*skipped.map(&:to_sym)).each do |attr_name, value|
          pp attr_name unless bike.send(attr_name).to_s == value.to_s
          expect(bike.send(attr_name).to_s).to eq value.to_s
        end
        expect(bike.frame_size_unit).to eq 'cm'
        expect(bike.rear_wheel_size.iso_bsd).to eq bike_attrs[:rear_wheel_bsd]
        expect(bike.primary_frame_color.name).to eq bike_attrs[:color]
        expect(bike.rear_gear_type.slug).to eq bike_attrs[:rear_gear_type_slug]
        expect(bike.front_gear_type.slug).to eq bike_attrs[:front_gear_type_slug]
        expect(bike.handlebar_type.slug).to eq bike_attrs[:handlebar_type_slug]
      end

      it 'creates a photos even if one fails' do
        manufacturer = FactoryGirl.create(:manufacturer)
        f_count = Feedback.count
        bike_attrs = {
          serial_number: '69 photo-test',
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: 'true',
          rear_wheel_bsd: '559',
          color: FactoryGirl.create(:color).name,
          example: true,
          year: '1969',
          owner_email: 'fun_times@examples.com'
        }
        photos = [
          'http://i.imgur.com/lybYl1l.jpg',
          'http://bikeindex.org/not_actually_a_thing_404_and_shit'
        ]
        post :create, bike: bike_attrs, organization_slug: @organization.slug, access_token: @organization.access_token, photos: photos
        bike = Bike.where(serial_number: '69 photo-test').first
        expect(bike.public_images.count).to eq(1)
        expect(bike.rear_wheel_size.iso_bsd).to eq 559
      end

      it 'creates a stolen record' do
        manufacturer = FactoryGirl.create(:manufacturer)
        @organization.users.first.update_attribute :phone, '123-456-6969'
        FactoryGirl.create(:country, iso: 'US')
        FactoryGirl.create(:state, abbreviation: 'Palace')
        # ListingOrderWorker.any_instance.should_receive(:perform).and_return(true)
        bike_attrs = { 
          serial_number: '69 stolen bike',
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: 'true',
          rear_wheel_size: 559,
          primary_frame_color_id: FactoryGirl.create(:color).id,
          owner_email: 'fun_times@examples.com',
          stolen: 'true',
          phone: '9999999',
          cycle_type_slug: 'bike'
        }
        stolen_record = { 
          date_stolen: '03-01-2013',
          theft_description: "This bike was stolen and that's no fair.",
          country: 'US',
          street: 'Cortland and Ashland',
          zipcode: '60622',
          state: 'Palace',
          police_report_number: '99999999',
          police_report_department: 'Chicago',
          locking_description: 'some locking description',
          lock_defeat_description: 'broken in some crazy way'
        }
        expect_any_instance_of(OwnershipCreator).to receive(:send_notification_email)
        expect do
          post :create, bike: bike_attrs, stolen_record: stolen_record, organization_slug: @organization.slug, access_token: @organization.access_token
        end.to change(Ownership, :count).by(1)
        expect(response.code).to eq('200')
        bike = Bike.unscoped.where(serial_number: '69 stolen bike').first
        expect(bike.rear_wheel_size.iso_bsd).to eq 559
        csr = bike.find_current_stolen_record
        expect(csr.address).to be_present
        expect(csr.phone).to eq('9999999')
        expect(csr.date_stolen).to eq(DateTime.strptime('03-01-2013 06', '%m-%d-%Y %H'))
        expect(csr.locking_description).to eq('some locking description')
        expect(csr.lock_defeat_description).to eq('broken in some crazy way')
      end

      it 'creates an example bike if the bike is from example, and include all the options' do
        FactoryGirl.create(:color, name: 'Black')
        org = FactoryGirl.create(:organization, name: 'Example organization')
        user = FactoryGirl.create(:user)
        FactoryGirl.create(:membership, user: user, organization: org)
        manufacturer = FactoryGirl.create(:manufacturer)
        org.save
        bike_attrs = {
          serial_number: '69 example bikez',
          cycle_type_id: FactoryGirl.create(:cycle_type, slug: 'gluey').id,
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: 'true',
          rear_wheel_size: 559,
          color: 'grazeen',
          handlebar_type_slug: FactoryGirl.create(:handlebar_type, slug: 'foo').slug,
          frame_material_slug: FactoryGirl.create(:frame_material, slug: 'whatevah').slug,
          description: 'something else',
          owner_email: 'fun_times@examples.com'
        }
        expect do
          expect do
            post :create, bike: bike_attrs, organization_slug: org.slug, access_token: org.access_token
          end.to change(Ownership, :count).by(1)
        end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
        expect(response.code).to eq('200')
        bike = Bike.unscoped.where(serial_number: '69 example bikez').first
        expect(bike.example).to be_truthy
        expect(bike.rear_wheel_size.iso_bsd).to eq 559
        expect(bike.paint.name).to eq('grazeen')
        expect(bike.description).to eq('something else')
        expect(bike.frame_material.slug).to eq('whatevah')
        expect(bike.handlebar_type.slug).to eq('foo')
      end

      it 'creates a record even if the post is a string' do
        manufacturer = FactoryGirl.create(:manufacturer)
        f_count = Feedback.count
        bike = {
          serial_number: '69 string',
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: 'true',
          rear_wheel_bsd: '559',
          color: FactoryGirl.create(:color).name,
          owner_email: 'jsoned@examples.com'
        }
        options = { bike: bike.to_json, organization_slug: @organization.slug, access_token: @organization.access_token }
        expect do
          post :create, options
        end.to change(Ownership, :count).by(1)
        expect(response.code).to eq('200')
      end

      it 'does not send an ownership email if it has no_email set' do
        manufacturer = FactoryGirl.create(:manufacturer)
        f_count = Feedback.count
        bike = { 
          serial_number: '69 string',
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: 'true',
          rear_wheel_bsd: '559',
          color: FactoryGirl.create(:color).name,
          owner_email: 'jsoned@examples.com',
          send_email: 'false'
        }
        options = { bike: bike.to_json, organization_slug: @organization.slug, access_token: @organization.access_token }
        expect do
          expect do
            post :create, options
          end.to change(Ownership, :count).by(1)
        end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
        expect(response.code).to eq('200')
      end
    end
  end
end
