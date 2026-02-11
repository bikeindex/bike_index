# frozen_string_literal: true

namespace :strava do
  desc "Create a Strava webhook subscription"
  task create_webhook: :environment do
    callback_url = ENV.fetch("STRAVA_WEBHOOK_CALLBACK_URL") {
      "#{ENV.fetch("BASE_URL")}/webhooks/strava"
    }
    verify_token = ENV.fetch("STRAVA_WEBHOOK_VERIFY_TOKEN")
    response = Integrations::StravaClient.create_webhook_subscription(callback_url, verify_token)
    puts "Status: #{response.status}"
    puts response.body.to_json
  end

  desc "View Strava webhook subscriptions"
  task view_webhooks: :environment do
    response = Integrations::StravaClient.view_webhook_subscriptions
    puts "Status: #{response.status}"
    puts response.body.to_json
  end

  desc "Delete a Strava webhook subscription"
  task :delete_webhook, [:id] => :environment do |_t, args|
    response = Integrations::StravaClient.delete_webhook_subscription(args[:id])
    puts "Status: #{response.status}"
    puts response.body.to_json
  end
end
