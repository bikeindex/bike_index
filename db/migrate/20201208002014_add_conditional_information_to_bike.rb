class AddConditionalInformationToBike < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :conditional_information, :jsonb, default: {}
  end
end
