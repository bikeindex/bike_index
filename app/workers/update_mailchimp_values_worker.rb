class UpdateMailchimpValuesWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(list, kind)
    if kind == "interest_category"
      update_interest_categories(list)
    elsif kind == "interest"
      update_interests(list)
    elsif kind == "tag"
      update_tags(list)
    elsif kind == "merge_field"
      update_merge_fields(list)
    else
      fail "Unknown kind: #{kind}"
    end
  end

  def mailchimp_integration
    @mailchimp_integration ||= MailchimpIntegration.new
  end

  def update_merge_fields(list)
    mailchimp_integration.get_merge_fields(list).each do |merge_field|
      next if MailchimpValue.where(kind: "merge_field", list: list, mailchimp_id: merge_field["id"])
        .first.present?
      MailchimpValue.create!(kind: "merge_field", list: list, data: merge_field)
    end
  end

  def update_tags(list)
    mailchimp_integration.get_tags(list).each do |tag|
      next if MailchimpValue.where(kind: "tag", list: list, mailchimp_id: tag["id"])
        .first.present?
      MailchimpValue.create!(kind: "tag", list: list, data: tag)
    end
  end

  def update_interests(list)
    interest_categories = MailchimpValue.interest_category.where(list: list)
    interests = interest_categories.map { |ic| mailchimp_integration.get_interests(ic) }.flatten
    interests.each do |interest|
      next if MailchimpValue.where(kind: "interest", list: list, mailchimp_id: interest["id"])
        .first.present?
      MailchimpValue.create!(kind: "interest", list: list, data: interest)
    end
  end

  def update_interest_categories(list)
    mailchimp_integration.get_interest_categories(list).each do |interest_category|
      next if MailchimpValue.where(kind: "interest_category", list: list, mailchimp_id: interest_category["id"])
        .first.present?
      MailchimpValue.create!(kind: "interest_category", list: list, data: interest_category)
    end
  end
end
