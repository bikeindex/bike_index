class CreateBugReports < ActiveRecord::Migration[8.1]
  def change
    create_table :bug_reports do |t|
      t.references :user
      t.text :email
      t.text :subject
      t.text :body
      t.boolean :is_member, default: false, null: false
      t.boolean :is_paid_organization, default: false, null: false
      t.boolean :is_paid_organization_staff, default: false, null: false
      t.integer :github_pull_request
      t.text :tags, array: true, default: [], null: false

      t.timestamps
    end
    add_index :bug_reports, :tags, using: :gin
  end
end
