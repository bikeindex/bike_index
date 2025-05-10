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
        expect(MarketplaceMessage.initial_message.pluck(:id)).to eq([marketplace_message.id])
        expect(MarketplaceMessage.reply_message.pluck(:id)).to eq([marketplace_message_reply.id])
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
    let!(:marketplace_message_2) { FactoryBot.create(:marketplace_message_reply, receiver: user) }
    let!(:marketplace_message_reply) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message) }

    it "returns the threads for user in the order by id" do
      expect(MarketplaceMessage.for_user(user).order(:id).pluck(:id)).to match_array([marketplace_message.id, marketplace_message_2.id, marketplace_message_reply.id])
      expect(MarketplaceMessage.distinct.pluck(:initial_record_id)).to match_array([marketplace_message.id, marketplace_message_2.initial_record_id])
      expect(MarketplaceMessage.threads_for_user(user).map(&:id)).to match_array([marketplace_message_reply.id, marketplace_message_2.id])
    end
  end
end
