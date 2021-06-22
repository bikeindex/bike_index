class FetchMailchimpMembersWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(list, page, count = 100, enqueue_all_pages = false)
    mailchimp_integration.get_members(list, page: page, count: count).each do |data|
      find_or_create_datum(list, data)
    end
    return true unless enqueue_all_pages
    # Calculated pages
    (mailchimp_integration.total_items / count).times do |page|
      FetchMailchimpMembersWorker.perform_async(list, page + 1, count)
    end
  end

  def mailchimp_integration
    @mailchimp_integration ||= MailchimpIntegration.new
  end

  def find_or_create_datum(list, data)
    email = EmailNormalizer.normalize(data["email_address"])
    mailchimp_datum = MailchimpDatum.find_by_email(email)
    mailchimp_datum ||= MailchimpDatum.new(email: email)
    mailchimp_datum.mailchimp_updated_at = TimeParser.parse(data["last_changed"])
    mailchimp_datum.set_calculated_attributes
    mailchimp_datum.data["lists"] += [list]
    mailchimp_datum.data["tags"] += data["tags"].map { |t| t["name"] }
    mailchimp_datum.add_mailchimp_interests(list, data["interests"])
    mailchimp_datum.add_mailchimp_merge_fields(list, data["merge_fields"])
    mailchimp_datum.save!
  end
end
