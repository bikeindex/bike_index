require "MailchimpMarketing"

class Integrations::Mailchimp
  API_KEY = ENV["MAILCHIMP_KEY"]
  SERVER_PREFIX = "us6" # I don't think this changes?

  LISTS = {
    organization: "b675299293",
    individual: "180a1141a4"
  }

  attr_accessor :total_items # For paginated lookups

  def self.list_id(str)
    LISTS[str&.to_sym]
  end

  def get_tags(list)
    result = client.lists.tag_search(self.class.list_id(list))
    @total_items = result["total_items"]
    result.dig("tags").map { |l| l.except("_links") }
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
    result = client.lists.get_list_members_info(self.class.list_id(list),
      offset: (count * page), count: count)
    @total_items = result["total_items"]
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
    client.lists.set_list_member(self.class.list_id(list), mailchimp_datum.subscriber_hash,
      member_update_hash(mailchimp_datum, list))
      .except("_links")
  rescue MailchimpMarketing::ApiError => e
    if e.status == 400 && e.to_s.match(/looks fake/i)
      # SHIT method to get error detail. e.detail returns nil
      return {"error" => e.to_s.gsub(/\A.*detail/, "").gsub(/",.*/, "").gsub(/\\+/, "")}
    end

    raise e # re-raise if it isn't a 404
  end

  def member_update_hash(mailchimp_datum, list)
    {
      email_address: mailchimp_datum.email,
      full_name: mailchimp_datum.full_name,
      status_if_new: mailchimp_datum.mailchimp_status,
      merge_fields: mailchimp_datum.mailchimp_merge_fields(list),
      interests: mailchimp_datum.mailchimp_interests(list)
    }
  end

  def update_member_tags(mailchimp_datum, list)
    client.lists.update_list_member_tags(self.class.list_id(list), mailchimp_datum.subscriber_hash,
      {tags: mailchimp_datum.mailchimp_tags(list)}.as_json)
  end

  def archive_member(mailchimp_datum, list)
    client.lists.delete_list_member(self.class.list_id(list), mailchimp_datum.subscriber_hash)
  rescue MailchimpMarketing::ApiError => e
    return if e.status == 404

    raise e # re-raise if it isn't a 404
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
