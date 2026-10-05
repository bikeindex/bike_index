require "rails_helper"

RSpec.describe ShopifyJobs::RegisterWebhooksJob, type: :job do
  let(:shopify_integration) { FactoryBot.create(:shopify_integration, shop_domain: "cool-bikes.myshopify.com") }
  let(:user_errors) { [] }
  let(:graphql_url) { /cool-bikes\.myshopify\.com\/admin\/api\/.+\/graphql\.json/ }

  before do
    WebMock.stub_request(:post, graphql_url).to_return { |request|
      data = if JSON.parse(request.body)["query"].include?("webhookSubscriptionCreate")
        {"t0" => {"userErrors" => user_errors}, "t1" => {"userErrors" => []}, "t2" => {"userErrors" => []}}
      else
        {"shop" => {"name" => "Cool Bikes", "myshopifyDomain" => "cool-bikes.myshopify.com"}}
      end
      {status: 200, body: {data:}.to_json, headers: {"Content-Type" => "application/json"}}
    }
  end
  after { WebMock.reset! }

  it "activates the integration" do
    described_class.new.perform(shopify_integration.id)
    expect(shopify_integration.reload).to have_attributes(status: "active", shop_name: "Cool Bikes")
    expect(shopify_integration.webhooks_registered_at).to be_present
  end

  context "a subscription is rejected" do
    let(:user_errors) { [{"field" => ["callbackUrl"], "message" => "Address is invalid"}] }

    it "records the error" do
      described_class.new.perform(shopify_integration.id)
      expect(shopify_integration.reload).to have_attributes(status: "error", last_error: "Address is invalid")
    end
  end

  # A reconnect after disconnecting from Bike Index, with the app still installed
  context "a subscription already exists" do
    let(:user_errors) { [{"field" => ["callbackUrl"], "message" => "Address for this topic has already been taken"}] }

    it "activates the integration" do
      described_class.new.perform(shopify_integration.id)
      expect(shopify_integration.reload).to have_attributes(status: "active", last_error: nil)
    end
  end
end
