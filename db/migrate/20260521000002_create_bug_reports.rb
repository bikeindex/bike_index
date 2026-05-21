class CreateBugReports < ActiveRecord::Migration[8.1]
  def change
    create_table :bug_reports do |t|
      t.string :from_address
      t.string :from_name
      t.string :subject
      t.text :body
      t.datetime :received_at
      t.references :inbound_email,
        foreign_key: {to_table: :action_mailbox_inbound_emails, on_delete: :nullify}

      t.timestamps
    end
  end
end
