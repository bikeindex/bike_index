# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketplaceRepliesMailbox, type: :mailbox do
  include ActionMailbox::TestHelper

  let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
  let(:buyer) { FactoryBot.create(:user_confirmed) }
  let(:seller) { marketplace_listing.seller }
  let!(:original_message) do
    FactoryBot.create(:marketplace_message,
      marketplace_listing:,
      sender: buyer,
      receiver: seller)
  end

  describe "#process" do
    context "when buyer replies to seller" do
      let(:inbound_email) do
        receive_inbound_email_from_mail(
          from: buyer.email,
          to: "reply+#{original_message.reply_token}@reply.bikeindex.org",
          subject: "Re: #{original_message.subject}",
          body: "Thanks for the info!"
        )
      end

      it "creates a new marketplace message" do
        expect { inbound_email }.to change(MarketplaceMessage, :count).by(1)

        reply = MarketplaceMessage.last
        expect(reply.sender).to eq buyer
        expect(reply.receiver).to eq seller
        expect(reply.body).to eq "Thanks for the info!"
        expect(reply.marketplace_listing).to eq marketplace_listing
        expect(reply.initial_record_id).to eq original_message.id
      end
    end

    context "when seller replies to buyer" do
      let(:inbound_email) do
        receive_inbound_email_from_mail(
          from: seller.email,
          to: "reply+#{original_message.reply_token}@reply.bikeindex.org",
          subject: "Re: #{original_message.subject}",
          body: "Happy to help!"
        )
      end

      it "creates a new marketplace message" do
        expect { inbound_email }.to change(MarketplaceMessage, :count).by(1)

        reply = MarketplaceMessage.last
        expect(reply.sender).to eq seller
        expect(reply.receiver).to eq buyer
        expect(reply.body).to eq "Happy to help!"
      end
    end

    context "with invalid reply token" do
      let(:inbound_email) do
        receive_inbound_email_from_mail(
          from: buyer.email,
          to: "reply+invalidtoken@reply.bikeindex.org",
          subject: "Re: something",
          body: "Hello"
        )
      end

      it "does not create a message" do
        expect { inbound_email }.not_to change(MarketplaceMessage, :count)
      end
    end

    context "with unauthorized sender" do
      let(:stranger) { FactoryBot.create(:user_confirmed) }
      let(:inbound_email) do
        receive_inbound_email_from_mail(
          from: stranger.email,
          to: "reply+#{original_message.reply_token}@reply.bikeindex.org",
          subject: "Re: #{original_message.subject}",
          body: "I want to join!"
        )
      end

      it "does not create a message" do
        expect { inbound_email }.not_to change(MarketplaceMessage, :count)
      end
    end

    context "with unknown sender email" do
      let(:inbound_email) do
        receive_inbound_email_from_mail(
          from: "unknown@example.com",
          to: "reply+#{original_message.reply_token}@reply.bikeindex.org",
          subject: "Re: #{original_message.subject}",
          body: "Who am I?"
        )
      end

      it "does not create a message" do
        expect { inbound_email }.not_to change(MarketplaceMessage, :count)
      end
    end
  end
end
