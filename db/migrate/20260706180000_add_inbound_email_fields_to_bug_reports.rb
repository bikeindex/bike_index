class AddInboundEmailFieldsToBugReports < ActiveRecord::Migration[8.1]
  def change
    add_column :bug_reports, :received_at, :datetime
    add_column :bug_reports, :from_name, :text
    add_reference :bug_reports, :inbound_email,
      foreign_key: {to_table: :action_mailbox_inbound_emails, on_delete: :nullify}
  end
end
