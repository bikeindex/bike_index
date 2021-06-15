require "MailchimpMarketing"

class MailchimpIntegration
  API_KEY = ENV["MAILCHIMP_KEY"]
  SERVER_PREFIX = "us6" # I don't think this changes?

  LISTS = {
    organization: "b675299293",
    individual: "180a1141a4"
  }

  def self.list_id(str)
    LISTS[str&.to_sym]
  end

  def get_tags(list)
    client.lists.tag_search(self.class.list_id(list))
      .dig("tags").map { |l| l.except("_links") }
  end

  def get_merge_fields(list)
    client.lists.get_list_merge_fields(self.class.list_id(list), count: 1000)
      .dig("merge_fields").map { |l| l.except("_links") }
  end

  def get_interest_categories(list)
    client.lists.get_list_interest_categories(self.class.list_id(list))
      .dig("categories").map { |l| l.except("_links") }
  end

  # requires a interest_category mailchimp_value
  def get_interests(mailchimp_value)
    client.lists.list_interest_category_interests(self.class.list_id(mailchimp_value.list), mailchimp_value.mailchimp_id)
      .dig("interests").map { |l| l.except("_links") }
  end

  def get_members(list, page:, count:)
    result = client.lists.get_list_members_info(self.class.list_id(list), page: page, count: count)
    # pp result
    result.dig("members").map { |l| l.except("_links") }
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
    # Get or Update member

    # Update tags
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
    client.lists.get_all_lists.as_json
      .dig("lists").map { |l| l.slice("id", "name") }
  end
end
