class AddPostalCodeAndRegionRecordIdToSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    change_table :social_accounts, bulk: true do |t|
      t.string :postal_code
      t.bigint :region_record_id
    end
  end
end
