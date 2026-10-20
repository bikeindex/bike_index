require "rails_helper"

RSpec.describe Backfills::StripeEventPayloadJob, type: :job do
  describe "perform" do
    let(:created_at) { Time.current - 1.year }
    let!(:handled) do
      StripeEvent.create!(name: "customer.subscription.created", stripe_id: "sub_1Handled", created_at:)
    end
    let!(:unhandled) { StripeEvent.create!(name: "charge.dispute.created", stripe_id: "dp_1Unhandled", created_at:) }
    let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-checkout.session.completed.json"))) }
    let!(:stored) { StripeEvent.create_from(Stripe::Event.construct_from(webhook_payload)) }

    it "sets the payload to the object id, and processed_at on the handled types" do
      described_class.new.perform

      expect(handled.reload).to have_attributes(stripe_event_id: nil,
        payload: {"data" => {"object" => {"id" => "sub_1Handled"}}})
      expect(handled.processed_at).to be_within(1).of created_at
      expect(unhandled.reload).to have_attributes(stripe_event_id: nil, processed_at: nil,
        payload: {"data" => {"object" => {"id" => "dp_1Unhandled"}}})
      expect(stored.reload).to have_attributes(processed_at: nil, payload: webhook_payload)
    end
  end
end
