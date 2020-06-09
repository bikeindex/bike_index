class EmailHotSheetWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(hot_sheet_id)
    hot_sheet = HotSheet.find(hot_sheet_id)

    return hot_sheet if hot_sheet.email_success?
  end
end
