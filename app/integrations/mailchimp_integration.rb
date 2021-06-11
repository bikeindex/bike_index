require "MailchimpMarketing"

class MailchimpIntegration
  API_KEY = ENV["MAILCHIMP_KEY"]
  SERVER_PREFIX = "us6" # I don't think this changes?
  AUDIENCE_IDS = {
    lead_for_bike_shop: 3,
    lead_for_city: 3,
    lead_for_school: 3,
    lead_for_law_enforcement: 3,
  }

  def client
    @client ||= MailchimpMarketing::Client.new(
      api_key: API_KEY,
      server: SERVER_PREFIX)
  end

  def get_audiences
    # Remove the _links, which are too much bs
    client.lists.get_all_lists
      .dig("lists").map { |l| l.except("_links") }
  end
end
