class AddRegionStringAndStreet2ToSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    change_table :social_accounts, bulk: true do |t|
      t.string :region_string
      t.string :street_2
    end
  end
end
