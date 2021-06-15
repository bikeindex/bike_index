class FetchMailchimpMembersWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(list, page, enqueue_all_pages = false, count = 100)
    mailchimp_integration.get_members(list, page: page, count: count).each do |data|
      find_or_create_datum(list, data)
    end
    return true unless enqueue_all_pages
  end

  def mailchimp_integration
    @mailchimp_integration ||= MailchimpIntegration.new
  end

  def find_or_create_datum(list, data)
    email = EmailNormalizer.normalize(data["email_address"])
    mailchimp_data = MailchimpDatum.find_by_email(email)
    mailchimp_data ||= MailchimpDatum.new(email: email)
    mailchimp_data.mailchimp_updated_at = TimeParser.parse(data["last_changed"])
    mailchimp_data.set_calculated_attributes
    mailchimp_data.data["lists"] += [list]
    mailchimp_data.data["tags"] += data["tags"].map { |t| t["name"] }
    interest_ids = data["interests"].select { |k, v| v }.keys
    mailchimp_data.data["mailchimp_interests"].merge!(list => interest_ids)
    mailchimp_data.save!
  end
end
