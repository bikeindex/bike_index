class UpdateMailchimpDatumJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 2

  UPDATE_MAILCHIMP = ENV["UPDATE_MAILCHIMP_ENABLED"] == "true"

  def perform(id, force_update = false)
    return false unless UPDATE_MAILCHIMP

    mailchimp_datum = MailchimpDatum.find(id)
    return false unless mailchimp_datum.should_update? || force_update

    mailchimp_datum.skip_update = true
    update_for_list(mailchimp_datum, "organization")
    update_for_list(mailchimp_datum, "individual")
    mailchimp_datum
  end

  def mailchimp_integration
    @mailchimp_integration ||= Integrations::Mailchimp.new
  end

  def update_for_list(mailchimp_datum, list)
    return archive_datum(mailchimp_datum, list) if mailchimp_datum.archived?
    return false unless mailchimp_datum.lists.include?(list)

    result = mailchimp_integration.update_member(mailchimp_datum, list)
    update_mailchimp_datum(mailchimp_datum, list, result)
    mailchimp_datum.reload
    if mailchimp_datum.mailchimp_tags(list).any?
      mailchimp_integration.update_member_tags(mailchimp_datum, list)
    end
  end

  def update_mailchimp_datum(mailchimp_datum, list, data)
    if data.key?("error").present?
      mailchimp_datum.data["mailchimp_error"] = data["error"]
      return mailchimp_datum.update(status: "unsubscribed")
    end
    updated_at = TimeParser.parse(data["last_changed"])
    if mailchimp_datum.mailchimp_updated_at.blank? || mailchimp_datum.mailchimp_updated_at < updated_at
      mailchimp_datum.mailchimp_updated_at = updated_at
    end
    mailchimp_datum.status = data["status"] unless data["status"] == mailchimp_datum.status
    mailchimp_datum.data["lists"] += [list]
    mailchimp_datum.add_mailchimp_tags(list, data["tags"])
    mailchimp_datum.add_mailchimp_interests(list, data["interests"])
    mailchimp_datum.add_mailchimp_merge_fields(list, data["merge_fields"])
    mailchimp_datum.save!
  end

  def archive_datum(mailchimp_datum, list)
    mailchimp_integration.archive_member(mailchimp_datum, list)
    # archive_member just returns a success true response
    # Add something to the data, so we don't attempt to archive endlessly
    mailchimp_datum.data["mailchimp_archived_at"] = Time.current.to_s
    mailchimp_datum.save
  end
end
