require 'spec_helper'

describe OwnershipCreator do
  describe 'owner_id' do
    it 'finds the user' do
      user = FactoryGirl.create(:confirmed_user, email: 'foo@email.com')
      create_ownership = OwnershipCreator.new
      allow(create_ownership).to receive(:find_owner_email).and_return('foo@email.com')
      expect(create_ownership.owner_id).to eq(user.id)
    end
    it "returns false if the user doesn't exist" do
      create_ownership = OwnershipCreator.new
      allow(create_ownership).to receive(:find_owner_email).and_return('foo')
      expect(create_ownership.owner_id).to be_nil
    end
  end

  describe 'find_owner_email' do
    it 'is the bike params unless owner_email is present' do
      bike = Bike.new
      allow(bike).to receive(:owner_email).and_return('foo@email.com')
      expect(OwnershipCreator.new(bike: bike).find_owner_email).to eq('foo@email.com')
    end
  end

  describe 'send_notification_email' do
    it 'sends a notification email' do
      ownership = Ownership.new
      allow(ownership).to receive(:id).and_return(2)
      expect do
        OwnershipCreator.new.send_notification_email(ownership)
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
    end

    it 'does not send a notification email for example bikes' do
      ownership = Ownership.new
      allow(ownership).to receive(:id).and_return(2)
      allow(ownership).to receive(:example).and_return(true)
      expect do
        OwnershipCreator.new.send_notification_email(ownership)
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
    end

    it 'does not send a notification email for ownerships with no_email set' do
      ownership = Ownership.new
      allow(ownership).to receive(:id).and_return(2)
      allow(ownership).to receive(:send_email).and_return(false)
      expect do
        OwnershipCreator.new.send_notification_email(ownership)
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
    end
  end

  describe 'new_ownership_params' do
    it 'creates new ownership attributes' do
      user = User.new
      bike = Bike.new
      allow(user).to receive(:id).and_return(69)
      allow(bike).to receive(:example).and_return(true)
      allow(bike).to receive(:id).and_return(1)
      create_ownership = OwnershipCreator.new(creator: user, bike: bike)
      allow(create_ownership).to receive(:owner_id).and_return(69)
      allow(create_ownership).to receive(:self_made?).and_return(false)
      allow(create_ownership).to receive(:find_owner_email).and_return('f@f.com')
      new_params = create_ownership.new_ownership_params
      expect(new_params[:bike_id]).to eq(1)
      expect(new_params[:example]).to eq(true)
      expect(new_params[:user_id]).to eq(69)
      expect(new_params[:owner_email]).to eq('f@f.com')
      expect(new_params[:claimed]).to be_falsey
      expect(new_params[:current]).to be_truthy
    end

    it 'creates a current new ownership if the ownership is created by the same person' do
      user = User.new
      bike = Bike.new
      allow(user).to receive(:id).and_return(69)
      allow(bike).to receive(:id).and_return(1)
      create_ownership = OwnershipCreator.new(creator: user, bike: bike)
      allow(create_ownership).to receive(:owner_id).and_return(69)
      allow(create_ownership).to receive(:self_made?).and_return(true)
      allow(create_ownership).to receive(:find_owner_email).and_return('f@f.com')
      new_params = create_ownership.new_ownership_params
      expect(new_params[:bike_id]).to eq(1)
      expect(new_params[:user_id]).to eq(69)
      expect(new_params[:owner_email]).to eq('f@f.com')
      expect(new_params[:claimed]).to be_truthy
      expect(new_params[:current]).to be_truthy
    end
  end

  describe 'mark_other_ownerships_not_current' do
    it 'marks existing ownerships as not current' do
      ownership1 = FactoryGirl.create(:ownership)
      bike = ownership1.bike
      ownership2 = FactoryGirl.create(:ownership, bike: bike)
      create_ownership = OwnershipCreator.new(bike: bike).mark_other_ownerships_not_current
      expect(ownership1.reload.current).to be_falsey
      expect(ownership2.reload.current).to be_falsey
    end
  end

  describe 'current_is_hidden' do
    it 'returns true if existing ownerships is user hidden' do
      ownership = FactoryGirl.create(:ownership, user_hidden: true)
      bike = ownership.bike
      bike.update_attribute :hidden, true
      create_ownership = OwnershipCreator.new(bike: bike)
      expect(create_ownership.current_is_hidden).to be_truthy
    end
    it 'returns false' do
      bike = Bike.new
      create_ownership = OwnershipCreator.new(bike: bike)
      expect(create_ownership.current_is_hidden).to be_falsey
    end
  end

  describe 'add_errors_to_bike' do
    xit 'adds the errors to the bike' do
      ownership = Ownership.new
      bike = Bike.new
      ownership.errors.add(:problem, 'BALLZ')
      creator = OwnershipCreator.new(bike: bike)
      creator.add_errors_to_bike(ownership)
      expect(bike.errors.messages[:problem]).to eq('BALLZ')
    end
  end

  describe 'create_ownership' do
    it 'calls mark not current and send notification and create a new ownership' do
      create_ownership = OwnershipCreator.new
      new_params = { bike_id: 1, user_id: 69, owner_email: 'f@f.com', creator_id: 69, claimed: true, current: true }
      allow(create_ownership).to receive(:mark_other_ownerships_not_current).and_return(true)
      allow(create_ownership).to receive(:new_ownership_params).and_return(new_params)
      expect(create_ownership).to receive(:send_notification_email).and_return(true)
      expect(create_ownership).to receive(:current_is_hidden).and_return(true)
      expect { create_ownership.create_ownership }.to change(Ownership, :count).by(1)
    end
    it 'calls mark not current and send notification and create a new ownership' do
      create_ownership = OwnershipCreator.new
      new_params = { creator_id: 69, claimed: true, current: true }
      allow(create_ownership).to receive(:mark_other_ownerships_not_current).and_return(true)
      allow(create_ownership).to receive(:new_ownership_params).and_return(new_params)
      expect(create_ownership).to receive(:add_errors_to_bike).and_return(true)
      expect { create_ownership.create_ownership }.to raise_error(OwnershipNotSavedError)
    end
  end
end
