# This fetches the mailchimp fields - it doesn't interact with users or mailchimp_datum

class UpdateMailchimpValuesWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(list = nil, kind = nil)
    return enqueue_all if list.blank?
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

  def enqueue_all
    MailchimpValue.lists.each do |list|
      MailchimpValue.kinds.each do |kind|
        UpdateMailchimpValuesWorker.perform_async(list, kind)
      end
    end
  end

  def mailchimp_integration
    @mailchimp_integration ||= Integrations::Mailchimp.new
  end

  def update_merge_fields(list)
    mailchimp_integration.get_merge_fields(list).each do |data|
      mailchimp_value = MailchimpValue.where(kind: "merge_field", list: list, mailchimp_id: data["tag"]).first
      if mailchimp_value.present?
        unless mailchimp_value.data == data.as_json
          mailchimp_value.update!(data: data)
        end
      else
        MailchimpValue.create!(kind: "merge_field", list: list, data: data)
      end
    end
  end

  def update_tags(list)
    mailchimp_integration.get_tags(list).each do |data|
      mailchimp_value = MailchimpValue.where(kind: "tag", list: list, mailchimp_id: data["id"]).first
      if mailchimp_value.present?
        unless mailchimp_value.data == data.as_json
          mailchimp_value.update!(data: data)
        end
      else
        MailchimpValue.create!(kind: "tag", list: list, data: data)
      end
    end
  end

  def update_interests(list)
    interest_categories = MailchimpValue.interest_category.where(list: list)
    interests = interest_categories.map { |ic| mailchimp_integration.get_interests(ic) }.flatten
    interests.each do |data|
      mailchimp_value = MailchimpValue.where(kind: "interest", list: list, mailchimp_id: data["id"]).first
      if mailchimp_value.present?
        unless mailchimp_value.data == data.as_json
          mailchimp_value.update!(data: data)
        end
      else
        MailchimpValue.create!(kind: "interest", list: list, data: data)
      end
    end
  end

  def update_interest_categories(list)
    mailchimp_integration.get_interest_categories(list).each do |data|
      mailchimp_value = MailchimpValue.where(kind: "interest_category", list: list, mailchimp_id: data["id"]).first
      if mailchimp_value.present?
        unless mailchimp_value.data == data.as_json
          mailchimp_value.update!(data: data)
        end
      else
        MailchimpValue.create!(kind: "interest_category", list: list, data: data)
      end
    end
  end
end
