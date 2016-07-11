class ChangeReferenceUrlToText < ActiveRecord::Migration
  def change
    change_column :stolen_notifications, :reference_url, :text
  end
end
