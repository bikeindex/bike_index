class CreateBannedEmailDomains < ActiveRecord::Migration[7.1]
  def change
    create_table :banned_email_domains do |t|
      t.string :domain
      t.references :creator

      t.timestamps
    end
  end
end
