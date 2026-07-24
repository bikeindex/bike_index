# frozen_string_literal: true

class AddIndexOnBugReportsStatus < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :bug_reports, :status, algorithm: :concurrently
  end
end
