class MigrateFeedbackHashToJsonb < ActiveRecord::Migration[4.2]
  def change
    rename_column :feedbacks, :feedback_hash, :feedback_hash_text
    add_column :feedbacks, :feedback_hash, :jsonb
  end
end
