class RemoveConditionalInformationFromBikes < ActiveRecord::Migration[5.2]
  def change
    remove_column :bikes, :conditional_information, :jsonb
  end
end
