class DropUserAddressAttrs < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :country_id, :bigint
    remove_column :users, :state_id, :bigint
    remove_column :users, :street, :string
    remove_column :users, :city, :string
    remove_column :users, :zipcode, :string
    remove_column :users, :neighborhood, :string
  end
end
