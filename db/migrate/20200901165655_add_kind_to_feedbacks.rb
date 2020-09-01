class AddKindToFeedbacks < ActiveRecord::Migration[5.2]
  def change
    add_column :feedbacks, :kind, :integer
  end
end
