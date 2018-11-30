class AddPartnerDataToUsers < ActiveRecord::Migration
  def change
    add_column :users, :partner_data, :json
  end
end
