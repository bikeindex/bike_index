require "rails_helper"

RSpec.describe OwnershipCreator do
  describe "send_notification_email" do
    it "sends a notification email" do
      ownership = Ownership.new
      allow(ownership).to receive(:id).and_return(2)
      expect do
        ownership.send_notification_and_update_other_ownerships
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
    end

    it "enqueues a notification email for example bikes (worker handles not sending)" do
      ownership = Ownership.new
      allow(ownership).to receive(:id).and_return(2)
      allow(ownership).to receive(:example).and_return(true)
      expect do
        ownership.send_notification_and_update_other_ownerships
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
    end

    it "enqueues a notification email for ownerships with no_email set (worker handles not sending" do
      ownership = Ownership.new
      allow(ownership).to receive(:id).and_return(2)
      allow(ownership).to receive(:send_email).and_return(false)
      expect do
        ownership.send_notification_and_update_other_ownerships
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
    end
  end

  describe "mark_other_ownerships_not_current" do
    it "marks existing ownerships as not current" do
      ownership1 = FactoryBot.create(:ownership)
      bike = ownership1.bike
      ownership2 = FactoryBot.create(:ownership, bike: bike)
      OwnershipCreator.new(bike: bike,
                           creator: ownership1.creator,
                           owner_email: "s@s.com").create_ownership
      expect(ownership1.reload.current).to be_falsey
      expect(ownership2.reload.current).to be_falsey
    end
  end

  describe "current_is_hidden" do
    it "returns true if existing ownerships is user hidden" do
      ownership = FactoryBot.create(:ownership, user_hidden: true)
      bike = ownership.bike
      bike.update_attribute :hidden, true
      ownership_creator = OwnershipCreator.new(bike: bike)
      expect(ownership_creator.current_is_hidden).to be_truthy
    end
    it "returns false" do
      bike = Bike.new
      ownership_creator = OwnershipCreator.new(bike: bike)
      expect(ownership_creator.current_is_hidden).to be_falsey
    end
  end

  describe "add_errors_to_bike" do
    xit "adds the errors to the bike" do
      ownership = Ownership.new
      bike = Bike.new
      ownership.errors.add(:problem, "BALLZ")
      creator = OwnershipCreator.new(bike: bike)
      creator.add_errors_to_bike(ownership)
      expect(bike.errors.messages[:problem]).to eq("BALLZ")
    end
  end

  describe "ownership_creator" do
    it "calls mark not current and send notification and create a new ownership" do
      ownership_creator = OwnershipCreator.new
      new_params = { bike_id: 1, user_id: 69, owner_email: "f@f.com", creator_id: 69, claimed: true, current: true }
      allow(ownership_creator).to receive(:new_ownership_params).and_return(new_params)
      expect(ownership_creator).to receive(:current_is_hidden).and_return(true)
      expect { ownership_creator.create_ownership }.to change(Ownership, :count).by(1)
    end
    it "calls mark not current and send notification and create a new ownership" do
      ownership_creator = OwnershipCreator.new
      new_params = { creator_id: 69, claimed: true, current: true }
      allow(ownership_creator).to receive(:new_ownership_params).and_return(new_params)
      expect(ownership_creator).to receive(:add_errors_to_bike).and_return(true)
      expect { ownership_creator.create_ownership }.to raise_error(OwnershipNotSavedError)
    end
  end
end
