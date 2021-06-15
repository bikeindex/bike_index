class FetchMailchimpMembersWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(list, page, count = 100, enqueue_all_pages = false)
    mailchimp_integration.get_members(list, page: page, count: count).each do |data|
      find_or_create_datum(list, data)
    end
    return true unless enqueue_all_pages
    additional_pages = mailchimp_integration.total_items / count
    additional_pages.times { |page| FetchMailchimpMembersWorker.perform_async(list, page + 1, count) }
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
    mailchimp_data.add_mailchimp_interests(list, data["interests"])
    mailchimp_data.mailchimp_merge_fields = data["merge_fields"]
    mailchimp_data.save!
  end
end
