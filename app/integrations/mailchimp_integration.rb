require "MailchimpMarketing"

class MailchimpIntegration
  API_KEY = ENV["MAILCHIMP_KEY"]
  SERVER_PREFIX = "us6" # I don't think this changes?

  LISTS = {
    organization: "1cdd",
    individual: "890adf"
  }

  def self.list_keys
    LISTS.keys
  end

  def client
    @client ||= MailchimpMarketing::Client.new(
      api_key: API_KEY,
      server: SERVER_PREFIX)
  end

  # Lists are called "Audiences" outside of the API
  def get_lists
    # Remove the _links, which are too much bs
    client.lists.get_all_lists
      .dig("lists").map { |l| l.except("_links") }
  end
end
