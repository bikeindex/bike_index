require "spec_helper"

describe Api::V1::UsersController do

  describe :current do 

    it "returns user_present = false if there is no user present" do
      get :current, format: :json
      response.code.should eq('200')
      response.headers['Access-Control-Allow-Origin'].should_not be_present
      response.headers['Access-Control-Request-Method'].should_not be_present
    end

    it "returns user_present if a user is present" do 
      # We need to test that cors isn't present
      u = FactoryGirl.create(:user)
      set_current_user(u)
      get :current, format: :json
      response.code.should eq('200')
      # pp response.body
      JSON.parse(response.body).should include("user_present" => true)
      response.headers['Access-Control-Allow-Origin'].should_not be_present
      response.headers['Access-Control-Request-Method'].should_not be_present
    end
  end

  describe :send_request do 
    it "actuallies send the mail" do
      Sidekiq::Testing.inline! do
        # We don't test that this is being added to Sidekiq
        # Because we're testing that sidekiq does what it 
        # Needs to do here. Slow tests, but we know it actually works :(
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        delete_request = { 
          request_type: 'bike_delete_request',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Some reason',
        }
        set_current_user(user)
        ActionMailer::Base.deliveries = []
        post :send_request, delete_request
        response.code.should eq('200')
        ActionMailer::Base.deliveries.should_not be_empty
      end
    end
    context 'manufacturer_update_manufacturer present' do
      it 'updates the manufacturer' do
        o = FactoryGirl.create(:ownership)
        manufacturer = FactoryGirl.create(:manufacturer)
        user = o.creator
        bike = o.bike
        update_manufacturer_request = { 
          request_type: 'manufacturer_update_manufacturer',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Need to update manufacturer',
          manufacturer_update_manufacturer: manufacturer.slug
        }
        set_current_user(user)
        post :send_request, update_manufacturer_request
        response.code.should eq('200')
        bike.reload
        expect(bike.manufacturer).to eq manufacturer
      end
    end

    context 'manufacturer_update_manufacturer present' do
      it 'does not make nil manufacturer' do
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        update_manufacturer_request = { 
          request_type: 'manufacturer_update_manufacturer',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Need to update manufacturer',
          manufacturer_update_manufacturer: 'doadsfizxcv'
        }
        set_current_user(user)
        post :send_request, update_manufacturer_request
        response.code.should eq('200')
        bike.reload
        expect(bike.manufacturer).to be_present
      end
    end

    context 'serial request mail' do
      it "doesn't create a new serial request mail" do 
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        serial_request = { 
          request_type: 'serial_update_request',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Some reason',
          serial_update_serial: 'some new serial'
        }
        set_current_user(user)
        SerialNormalizer.any_instance.should_receive(:save_segments)
        expect {
          post :send_request, serial_request
        }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
        response.code.should eq('200')
        bike.reload.serial_number.should eq('some new serial')
      end
    end

    it "it untsvs a bike" do 
      t = Time.now - 1.minute
      stolen_record = FactoryGirl.create(:stolen_record, tsved_at: t)
      o = FactoryGirl.create(:ownership, bike: stolen_record.bike)
      user = o.creator
      bike = o.bike
      bike.update_attribute :current_stolen_record_id, bike.find_current_stolen_record.id
      serial_request = { 
        request_type: 'serial_update_request',
        user_id: user.id,
        request_bike_id: bike.id,
        request_reason: 'Some reason',
        serial_update_serial: 'some new serial'
      }
      set_current_user(user)
      SerialNormalizer.any_instance.should_receive(:save_segments)
      post :send_request, serial_request
      response.code.should eq('200')
      bike.reload
      bike.serial_number.should eq('some new serial')
      stolen_record.reload
      stolen_record.tsved_at.should be_nil
    end


    it "creates a new recovery request mail" do 
      Sidekiq::Testing.inline! do 
        # We don't test that this is being added to Sidekiq
        # Because we're testing that sidekiq does what it 
        # Needs to do here.
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        stolen_record = FactoryGirl.create(:stolen_record, bike: bike)
        bike.update_attribute :stolen, true
        recovery_request = { 
          request_type: 'bike_recovery',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Some reason',
          index_helped_recovery: 'true',
          can_share_recovery: 'true',
          mark_recovered_stolen_record_id: stolen_record.id
        }
        set_current_user(user)
        bike.reload.update_attributes(stolen: false, current_stolen_record_id: nil)
        bike.reload
        post :send_request, recovery_request.as_json
        response.code.should eq('200')
        flash[:error].should_not be_present
        bike.reload.stolen.should be_false
        # ALSO MAKE SURE IT RECOVERY NOTIFIES
        stolen_record.reload.current.should be_false
        stolen_record.bike.should eq(bike)
        stolen_record.date_recovered.should be_present
        stolen_record.recovery_posted.should be_false
        stolen_record.index_helped_recovery.should be_true
        stolen_record.can_share_recovery.should be_true
      end
    end
      
    it "does not create a new serial request mailer if a user isn't present" do 
      bike = FactoryGirl.create(:bike)
      message = { request_bike_id: bike.id, serial_update_serial: 'some update', request_reason: 'Some reason' }
      # pp message
      post :send_request, message, format: :json
      response.code.should eq('403')
    end

    it "does not create a new serial request mailer if wrong user user is present" do 
      o = FactoryGirl.create(:ownership)
      bike = o.bike
      user = FactoryGirl.create(:user)
      set_current_user(user)
      params = { request_bike_id: bike.id, serial_update_serial: 'some update', request_reason: 'Some reason' }
      post :send_request, params
      # pp response 
      response.code.should eq('403')
    end
  end

end
