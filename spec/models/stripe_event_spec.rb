require "rails_helper"

RSpec.describe StripeEvent, type: :model do
  let(:stripe_event) { StripeEvent.create_from(Stripe::Event.construct_from(webhook_payload)) }

  describe "create_from" do
    let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-checkout.session.completed.json"))) }
    let(:target_attributes) do
      {
        name: "checkout.session.completed",
        stripe_event_id: "evt_0Tb1opm0T0GBfX0veedyxQTJ",
        stripe_id: "cs_test_a1XzIICn9NZ2p5RoNzP8GLCSMog4c2noU1G4d4V8sgs3MVjZxEYysztFHl",
        stripe_account_id: nil,
        payload: webhook_payload
      }
    end

    it "stores the payload once per Stripe event" do
      expect { stripe_event }.to change(StripeEvent, :count).by 1
      expect(stripe_event).to have_attributes target_attributes
      expect(stripe_event.reload).to have_attributes target_attributes

      expect { StripeEvent.create_from(Stripe::Event.construct_from(webhook_payload)) }
        .to_not change(StripeEvent, :count)
    end

    context "with a Connect event" do
      let(:webhook_payload) do
        {
          "id" => "evt_1Connect", "object" => "event", "type" => "account.updated", "account" => "acct_1Seller",
          "data" => {"object" => {"id" => "acct_1Seller", "object" => "account", "payouts_enabled" => true}}
        }
      end
      let(:target_attributes) do
        {name: "account.updated", stripe_event_id: "evt_1Connect", stripe_id: "acct_1Seller",
         stripe_account_id: "acct_1Seller", payload: webhook_payload}
      end

      it "stores the connected account" do
        expect(stripe_event).to have_attributes target_attributes
        expect(stripe_event.known_event?).to be_falsey
      end
    end
  end
end
