require "rails_helper"

RSpec.describe MarketplaceMessage, type: :model do
  describe "factory" do
    let(:marketplace_message) { FactoryBot.create(:marketplace_message) }
    let(:seller_id) { marketplace_message.marketplace_listing.seller_id }
    it "is valid" do
      expect(marketplace_message).to be_valid
      expect(marketplace_message.receiver_id).to eq seller_id
      expect(marketplace_message.initial_message?).to be_truthy
      expect(marketplace_message.kind).to eq "sender_buyer"
      expect(marketplace_message.initial_record_id).to eq marketplace_message.id
      expect(marketplace_message.messages_prior_count).to eq 0
      expect(marketplace_message.item).to be_present
      expect(MarketplaceMessage.any_for_user?).to be_falsey
      expect(MarketplaceMessage.any_for_user?(marketplace_message.sender)).to be_truthy
      expect(MarketplaceMessage.any_for_user?(marketplace_message.receiver)).to be_truthy
    end
    context "reply" do
      let(:marketplace_message_reply) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message) }
      it "is valid" do
        expect(marketplace_message).to be_valid
        expect(marketplace_message_reply).to be_valid

        expect(marketplace_message_reply.initial_record_id).to eq marketplace_message.id
        expect(marketplace_message_reply.sender_id).to eq marketplace_message.receiver_id
        expect(marketplace_message_reply.receiver_id).to eq marketplace_message.sender_id
        expect(marketplace_message_reply.marketplace_listing_id).to eq marketplace_message.marketplace_listing_id
        expect(marketplace_message_reply.initial_message?).to be_falsey
        expect(marketplace_message_reply.kind).to eq "sender_seller"
        expect(marketplace_message_reply.messages_prior_count).to eq 1
        expect(MarketplaceMessage.initial_message.pluck(:id)).to eq([marketplace_message.id])
        expect(MarketplaceMessage.reply_message.pluck(:id)).to eq([marketplace_message_reply.id])
      end
      context "passed a receiver" do
        let(:receiver) { FactoryBot.create(:user) }
        let(:marketplace_message) { FactoryBot.create(:marketplace_message_reply, receiver:) }
        it "is valid" do
          expect(marketplace_message).to be_valid
          expect(marketplace_message.receiver_id).to eq receiver.id
          expect(marketplace_message.initial_record.sender_id).to eq receiver.id
          expect(marketplace_message.initial_record.receiver_id).to eq marketplace_message.sender_id
        end
      end
    end
    context "reply passed sender" do
      let(:marketplace_message_reply) do
        FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message,
          sender_id: marketplace_message.sender_id)
      end
      it "is valid" do
        expect(marketplace_message).to be_valid
        expect(marketplace_message_reply).to be_valid

        expect(marketplace_message_reply.initial_record_id).to eq marketplace_message.id
        expect(marketplace_message_reply.sender_id).to eq marketplace_message.sender_id
        expect(marketplace_message_reply.receiver_id).to eq marketplace_message.receiver_id
        expect(marketplace_message_reply.marketplace_listing_id).to eq marketplace_message.marketplace_listing_id
        expect(marketplace_message_reply.initial_message?).to be_falsey
        expect(marketplace_message.kind).to eq "sender_buyer"
      end
    end
  end

  describe "threads_for_user" do
    let(:marketplace_message) { FactoryBot.create(:marketplace_message) }
    let(:user) { marketplace_message.receiver }
    let(:marketplace_message_1) { FactoryBot.create(:marketplace_message, sender: user) }
    let(:marketplace_message_2) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message_1, receiver: user) }
    let(:marketplace_message_reply) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message) }

    it "returns the threads for user in the order by id" do
      expect(marketplace_message).to be_valid
      expect(marketplace_message_1).to be_valid
      expect(marketplace_message_1.receiver_id).to_not eq user.id
      expect(marketplace_message_1.sender_id).to eq user.id
      expect(marketplace_message_2).to be_valid
      expect(marketplace_message_2.receiver_id).to eq user.id
      expect(marketplace_message_2.sender_id).to_not eq user.id
      expect(marketplace_message_reply).to be_valid
      expect(MarketplaceMessage.for_user(user).order(:id).pluck(:id)).to match_array([marketplace_message.id, marketplace_message_1.id, marketplace_message_2.id, marketplace_message_reply.id])
      expect(MarketplaceMessage.distinct.pluck(:initial_record_id)).to match_array([marketplace_message.id, marketplace_message_2.initial_record_id])
      expect(MarketplaceMessage.threads_for_user(user).map(&:id)).to match_array([marketplace_message_reply.id, marketplace_message_2.id])
    end
  end

  describe "for" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }
    let(:seller) { marketplace_listing.seller }
    let(:sender) { FactoryBot.create(:user_confirmed) }
    let(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:, sender:) }
    let(:marketplace_message_reply) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message) }
    let(:other_user) { FactoryBot.create(:user_confirmed) }

    it "returns the marketplace_messages if present" do
      expect(MarketplaceMessage.for(user: sender, marketplace_listing:).pluck(:id)).to eq([])
      expect(marketplace_message).to be_present
      expect(MarketplaceMessage.for(user: sender, marketplace_listing:).pluck(:id)).to eq([marketplace_message.id])
      expect(MarketplaceMessage.for(user: sender, marketplace_listing:, initial_record_id: marketplace_message.id).pluck(:id)).to eq([marketplace_message.id])
      expect(MarketplaceMessage.for(user: seller, marketplace_listing:, initial_record_id: marketplace_message.id).pluck(:id)).to eq([marketplace_message.id])
      expect do
        MarketplaceMessage.for(user: seller, marketplace_listing:).pluck(:id)
      end.to raise_error(ActiveRecord::RecordNotFound)

      # It finds both the messages when passed correct parameters
      both_ids = [marketplace_message.id, marketplace_message_reply.id]
      expect(MarketplaceMessage.for(user: sender, marketplace_listing:).pluck(:id)).to match_array both_ids
      expect(MarketplaceMessage.for(user: sender, marketplace_listing:, initial_record_id: marketplace_message.id).pluck(:id)).to match_array both_ids
      expect(MarketplaceMessage.for(user: seller, marketplace_listing:, initial_record_id: marketplace_message.id).pluck(:id)).to match_array both_ids
      expect do
        MarketplaceMessage.for(user: seller, marketplace_listing:).pluck(:id)
      end.to raise_error(ActiveRecord::RecordNotFound)

      # it raises if passed a different user not in the thread
      expect do
        MarketplaceMessage.for(user: other_user, marketplace_listing:, initial_record_id: marketplace_message.id).pluck(:id)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "other_user_display_name" do
    let(:receiver) { User.new(id: 12, name: "Seth H", username: "xxxyyy") }
    let(:sender) { User.new(id: 32, name: nil, username: "123456789101112") }
    let(:marketplace_message) { MarketplaceMessage.new(sender:, receiver:) }
    it "returns the other user marketplace_message_name" do
      expect(marketplace_message.other_user(sender)).to eq([receiver, :receiver])
      expect(marketplace_message.other_user(32)).to eq([receiver, :receiver])
      expect(marketplace_message.other_user_display_and_id(sender)).to eq(["Seth H", 12])
      expect(marketplace_message.other_user(receiver)).to eq([sender, :sender])
      expect(marketplace_message.other_user(12)).to eq([sender, :sender])
      expect(marketplace_message.other_user_display_and_id(receiver)).to eq(["12345678...", 32])
    end

    context "user deleted" do
      let(:marketplace_message) { MarketplaceMessage.new(sender_id: 11, receiver:) }
      it "returns the other user marketplace_message_name" do
        expect(marketplace_message.other_user(11)).to eq([receiver, :receiver])
        expect(marketplace_message.other_user_display_and_id(11)).to eq(["Seth H", 12])
        expect(marketplace_message.other_user(receiver)).to eq([nil, :sender])
        expect(marketplace_message.other_user(12)).to eq([nil, :sender])
        expect(marketplace_message.other_user_display_and_id(receiver)).to eq(["(user removed)", 11])
      end
    end
  end
end
