# frozen_string_literal: true

class AddStatusToBugReports < ActiveRecord::Migration[8.0]
  def change
    add_column :bug_reports, :status, :integer, default: 0, null: false
  end
end
