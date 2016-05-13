require 'spec_helper'

describe StolenNotificationsController do
  before :each do
    @user = FactoryGirl.create(:user)
    @user2 = FactoryGirl.create(:user, name: 'User2')
    @bike = FactoryGirl.create(:bike)
    @ownership = FactoryGirl.create(:ownership, user: @user, bike: @bike, current: true)
  end
  describe 'create' do
    describe 'success' do
      let(:stolenNotification_attributes) do
        stolenNotification = FactoryGirl.attributes_for(:stolenNotification)
        stolenNotification[:bike_id] = @bike.id
        stolenNotification
      end

      it 'creates a Stolen Notification record' do
        set_current_user(@user)
        expect do
          post :create, stolenNotification: stolenNotification_attributes
        end.to change(StolenNotification, :count).by(1)
      end

      it 'enqueues the stolen notification email job' do
        set_current_user(@user)
        expect do
          post :create, stolenNotification: stolenNotification_attributes
        end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      end
    end

    describe 'failure' do
      let(:stolenNotification_attributes) do
        stolenNotification = FactoryGirl.attributes_for(:stolenNotification, receiver: nil, bike: @bike)
        stolenNotification
      end

      it 'does not work unless there is a user logged in' do
        expect do
          post :create, stolenNotification: stolenNotification_attributes
        end.not_to change(StolenNotification, :count)
      end
    end
  end
end
