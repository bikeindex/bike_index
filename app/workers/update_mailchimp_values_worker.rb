class UpdateMailchimpValuesWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(list, kind)
    if kind == "interest_category"
      update_interest_categories(list)
    end
  end

  def update_interest_categories(list)

  end
end
