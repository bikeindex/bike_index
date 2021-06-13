require "MailchimpMarketing"

class MailchimpIntegration
  API_KEY = ENV["MAILCHIMP_KEY"]
  SERVER_PREFIX = "us6" # I don't think this changes?

  LISTS = {
    organization: "b675299293",
    individual: "180a1141a4",
    from_bike_index: ""
  }

  def self.list_id(str)
    LISTS[str&.to_sym]
  end

  def get_member(mailchimp_datum, list = nil)
    list ||= mailchimp_datum.lists.first
    begin
      client.lists.get_list_member(self.class.list_id(list),
        mailchimp_datum.subscriber_hash)
    rescue MailchimpMarketing::ApiError => e
      return if e.status == 404
      raise e # re-raise if it isn't a 404
    end
  end

  def update_member(mailchimp_datum, list)
  end

  def member_update_hash(mailchimp_datum, list)
    {
      email: mailchimp_datum.email,
      full_name: mailchimp_datum.full_name,
      status: mailchimp_datum.mailchimp_status,
      merge_fields: mailchimp_datum.merge_fields,
      interests: mailchimp_datum.interests
    }
  end

  def client
    @client ||= MailchimpMarketing::Client.new(
      api_key: API_KEY,
      server: SERVER_PREFIX
    )
  end

  # Lists are called "Audiences" outside of the API
  def get_lists
    # Remove the _links, which are too much bs
    client.lists.get_all_lists
      .dig("lists").map { |l| l.except("_links") }
  end

  def tags
    {
      in_index: "In Bike Index",
      not_organization_creator: "Not organization creator"
    }
  end
end
