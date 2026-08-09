class AddReceiverToBugReports < ActiveRecord::Migration[8.1]
  def change
    add_column :bug_reports, :receiver, :text
    add_index :bug_reports, :receiver
  end
end
