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
        expect(marketplace_message_reply.buyer_id).to eq marketplace_message.sender_id

        expect(marketplace_message.kind).to eq "sender_buyer"
        expect(marketplace_message.buyer_id).to eq marketplace_message.sender_id
      end
    end
  end

  describe "sender_is_user_from_initial_record validation" do
    let(:marketplace_message) { FactoryBot.create(:marketplace_message) }
    let(:sender_id) { marketplace_message.sender_id }
    let(:receiver_id) { marketplace_message.receiver_id }
    let(:other_user_id) { FactoryBot.create(:user_confirmed).id }
    let(:marketplace_message_reply) { FactoryBot.build(:marketplace_message_reply, initial_record: marketplace_message, sender_id:, receiver_id:) }

    it "is invalid" do
      expect(marketplace_message_reply).to be_valid
      # When sender isn't original
      marketplace_message.attributes = {sender_id: other_user_id}
      expect(marketplace_message_reply).to_not be_valid
      expect(marketplace_message_reply.errors.full_messages).to eq(["user isn't one of the original message users"])
      # when receiver isn't original
      marketplace_message.attributes = {sender_id:, receiver_id: other_user_id}
      expect(marketplace_message_reply).to_not be_valid
      expect(marketplace_message_reply.errors.full_messages).to eq(["user isn't one of the original message users"])
      # when blank, different error
      marketplace_message_reply.attributes = {sender_id: nil, receiver_id: nil}
      expect(marketplace_message_reply).to_not be_valid
      expect(marketplace_message_reply.errors.full_messages).to eq(["Sender can't be blank"])
    end
  end

  describe "threads_for_user" do
    let(:marketplace_message_1) { FactoryBot.create(:marketplace_message) }
    let(:user) { marketplace_message_1.receiver }
    let!(:marketplace_message_2_reply) { FactoryBot.create(:marketplace_message_reply, receiver: user) }
    let(:marketplace_message_2) { marketplace_message_2_reply.initial_record }
    let!(:marketplace_message_1_reply) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message_1, receiver: user) }
    let!(:marketplace_message_3) { FactoryBot.create(:marketplace_message, sender: user) }
    let!(:marketplace_message_other) { FactoryBot.create(:marketplace_message) }

    it "returns the threads for user in the order by id" do
      expect(marketplace_message_1.receiver_id).to eq user.id
      expect(marketplace_message_2.sender_id).to eq user.id
      expect(marketplace_message_1_reply.receiver_id).to eq user.id
      expect(marketplace_message_3.sender_id).to eq user.id

      expect(MarketplaceMessage.order(id: :desc).pluck(:id)).to eq([marketplace_message_other.id, marketplace_message_3.id, marketplace_message_1_reply.id, marketplace_message_2_reply.id, marketplace_message_2.id, marketplace_message_1.id])
      expect(MarketplaceMessage.for_user(user).order(id: :desc).pluck(:id)).to eq([marketplace_message_3.id, marketplace_message_1_reply.id, marketplace_message_2_reply.id, marketplace_message_2.id, marketplace_message_1.id])

      expect(MarketplaceMessage.threads_for_user(user).map(&:id)).to match_array([marketplace_message_3.id, marketplace_message_1_reply.id, marketplace_message_2_reply.id])
      expect(MarketplaceMessage.distinct_threads.map(&:id)).to eq([marketplace_message_other.id, marketplace_message_3.id, marketplace_message_1_reply.id, marketplace_message_2_reply.id])
    end
  end

  describe "thread_for!" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }
    let(:marketplace_listing_id) { "ml_#{marketplace_listing.id}" }
    let(:seller) { marketplace_listing.seller }
    let(:sender) { FactoryBot.create(:user_confirmed) }
    let(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:, sender:) }
    let(:marketplace_message_reply) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message) }
    let(:other_user) { FactoryBot.create(:user_confirmed) }

    it "returns the marketplace_messages if present" do
      expect(MarketplaceMessage.thread_for!(user: sender, id: marketplace_listing_id)).to eq([])
      expect(marketplace_message).to be_present
      expect(MarketplaceMessage.thread_for!(user: sender, id: marketplace_listing_id).pluck(:id)).to eq([marketplace_message.id])
      expect(MarketplaceMessage.thread_for!(user: sender, id: marketplace_message.id).pluck(:id)).to eq([marketplace_message.id])
      expect(MarketplaceMessage.thread_for!(user: seller, id: marketplace_message.id).pluck(:id)).to eq([marketplace_message.id])
      expect(MarketplaceMessage.send(:thread_for, user: seller, id: marketplace_listing_id)).to be_blank
      expect do
        MarketplaceMessage.thread_for!(user: seller, id: marketplace_listing_id).pluck(:id)
      end.to raise_error(ActiveRecord::RecordNotFound)

      # It finds both the messages when passed correct parameters
      both_ids = [marketplace_message.id, marketplace_message_reply.id]
      expect(MarketplaceMessage.thread_for!(user: sender, id: marketplace_listing_id).pluck(:id)).to match_array both_ids
      expect(MarketplaceMessage.thread_for!(user: sender, id: marketplace_message.id).pluck(:id)).to match_array both_ids
      expect(MarketplaceMessage.thread_for!(user: sender, id: marketplace_message_reply.id).pluck(:id)).to match_array both_ids
      expect(MarketplaceMessage.thread_for!(user: seller, id: marketplace_message.id).pluck(:id)).to match_array both_ids
      expect(MarketplaceMessage.thread_for!(user: seller, id: marketplace_message_reply.id).pluck(:id)).to match_array both_ids
      expect do
        MarketplaceMessage.thread_for!(user: seller, id: marketplace_listing_id).pluck(:id)
      end.to raise_error(ActiveRecord::RecordNotFound)

      # it raises if passed a different user not in the thread
      expect do
        MarketplaceMessage.thread_for!(user: other_user, id: marketplace_message.id).pluck(:id)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "can_send_message?" do
    let(:user) { FactoryBot.create(:user) }
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :with_address_record, status:) }
    let(:seller) { marketplace_listing.seller }
    let(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:, sender: user) }
    let(:status) { :for_sale }

    it "is truthy" do
      expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:)).to be_truthy
      expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:)).to be_truthy

      expect(marketplace_message).to be_valid
      expect(MarketplaceMessage.can_send_message?(user: seller, marketplace_listing:, marketplace_message:)).to be_truthy
      expect(MarketplaceMessage.can_see_messages?(user: seller, marketplace_listing:, marketplace_message:)).to be_truthy
      expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
      expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message:)).to be_truthy

      # It is falsey for another user
      user2 = FactoryBot.create(:user_confirmed)
      # even if the user has a marketplace message
      FactoryBot.create(:marketplace_message, marketplace_listing:, sender: user2)
      expect(MarketplaceMessage.can_send_message?(user: user2, marketplace_listing:, marketplace_message:)).to be_falsey
      expect(MarketplaceMessage.can_see_messages?(user: user2, marketplace_listing:, marketplace_message:)).to be_falsey
    end

    context "with draft" do
      let(:status) { :draft }
      it "is falsey, unless message exists" do
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:)).to be_falsey
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:)).to be_falsey

        expect(MarketplaceMessage.can_send_message?(user: seller, marketplace_listing:)).to be_falsey
        # New marketplace message doesn't work
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message: MarketplaceMessage.new))
          .to be_falsey

        # If for example, there was a message but then the item was marked draft again
        expect(marketplace_message).to be_valid
        expect(marketplace_message.initial_message).to be_truthy
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
        # IDK, should these be truthy? Probably...
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:)).to be_truthy
      end
    end

    context "with sold" do
      let(:status) { :sold }
      it "is falsey, unless message exists" do
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:)).to be_falsey
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:)).to be_falsey

        expect(marketplace_message).to be_valid
        expect(MarketplaceMessage.can_send_message?(user: seller, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user: seller, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:)).to be_truthy
      end
    end

    context "with removed" do
      let(:status) { :removed }
      it "is falsey" do
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:)).to be_falsey
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:)).to be_falsey

        expect(MarketplaceMessage.can_send_message?(user: seller, marketplace_listing:)).to be_falsey

        # Functionally, I think removed should work the same way as sold
        expect(marketplace_message).to be_valid
        expect(MarketplaceMessage.can_send_message?(user: seller, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user: seller, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
      end
    end

    context "with built message" do
      let(:marketplace_message) { FactoryBot.build(:marketplace_message, marketplace_listing:, sender: user) }
      it "is truthy" do
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
      end
    end

    context "with built reply" do
      let(:initial_record) { FactoryBot.create(:marketplace_message, marketplace_listing:, sender: initial_sender) }
      let(:initial_sender) { user }
      let(:marketplace_message) { FactoryBot.build(:marketplace_message, marketplace_listing:, sender: user, initial_record:, marketplace_listing: nil) }
      it "is truthy" do
        expect(initial_record).to be_valid
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message: initial_record)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message: initial_record)).to be_truthy
        expect(marketplace_message).to be_valid
        expect(marketplace_message.marketplace_listing_id).to eq initial_record.marketplace_listing_id
        expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
        expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message:)).to be_truthy
      end
      context "with initial sender not user" do
        let(:initial_sender) { FactoryBot.create(:user_confirmed) }
        it "is falsey" do
          expect(initial_record).to be_valid
          expect(initial_record.user_ids).to_not include(user.id)
          expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message: initial_record)).to be_falsey
          expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message: initial_record)).to be_falsey

          expect(MarketplaceMessage.can_send_message?(user:, marketplace_listing:, marketplace_message:)).to be_falsey
          expect(MarketplaceMessage.can_see_messages?(user:, marketplace_listing:, marketplace_message:)).to be_falsey
        end
      end
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

  describe "duplicate_of" do
    let(:marketplace_message_2) { FactoryBot.create(:marketplace_message_reply) }
    let(:marketplace_message_1) { marketplace_message_2.initial_record }
    let(:body) { "Thank you" }

    it "returns true for a duplicate" do
      expect(marketplace_message_2.ignored_duplicate?).to be_falsey
      expect(marketplace_message_2).to be_valid
      duplicate = MarketplaceMessage.new(sender_id: marketplace_message_2.sender_id, body:, initial_record_id: marketplace_message_1.id)
      expect(duplicate).to be_valid
      expect(duplicate.ignored_duplicate?).to be_truthy
      expect(duplicate.save).to be_truthy
    end
  end
end
