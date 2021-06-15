class UpdateMailchimpDatumWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(id)
    mailchimp_datum = MailchimpDatum.find(id)
    if mailchimp_datum.lists.include?("organization")
      result = mailchimp_integration.update_member(mailchimp_datum, "organization")
      update_mailchimp_datum("organization", mailchimp_datum, result)
      mailchimp_datum.reload
      # Update tags
    end
    if mailchimp_datum.lists.include?("individual")
      result = mailchimp_integration.update_member(mailchimp_datum, "individual")
      update_mailchimp_datum("individual", mailchimp_datum, result)
      # update tags
    end
    mailchimp_datum
  end

  def mailchimp_integration
    @mailchimp_integration ||= MailchimpIntegration.new
  end

  def update_mailchimp_datum(list, mailchimp_datum, data)
    updated_at = TimeParser.parse(data["last_changed"])
    if mailchimp_datum.mailchimp_updated_at.blank? || mailchimp_datum.mailchimp_updated_at < updated
      mailchimp_datum.mailchimp_updated_at = updated_at
    end
    mailchimp_datum.data["lists"] += [list]
    mailchimp_datum.data["tags"] += data["tags"].map { |t| t["name"] }
    mailchimp_datum.add_mailchimp_interests(list, data["interests"])
    mailchimp_datum.add_mailchimp_merge_fields(list, data["merge_fields"])
    mailchimp_datum.save!
  end
end
