class AddTypeToFeedbacks < ActiveRecord::Migration
  def change
    add_column :feedbacks, :feedback_type, :string
  end
end
