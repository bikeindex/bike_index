class UpdateMailchimpDatumWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 5

  def perform(mailchimp_datum_id)
  end
end
