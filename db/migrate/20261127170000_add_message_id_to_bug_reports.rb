class AddMessageIdToBugReports < ActiveRecord::Migration[8.1]
  def change
    add_column :bug_reports, :message_id, :text
  end
end
