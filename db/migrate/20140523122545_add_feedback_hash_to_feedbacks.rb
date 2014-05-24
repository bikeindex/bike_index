class AddFeedbackHashToFeedbacks < ActiveRecord::Migration
  def change
    add_column :feedbacks, :feedback_hash, :text
  end
end
