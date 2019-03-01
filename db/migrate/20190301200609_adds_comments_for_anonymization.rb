class AddsCommentsForAnonymization < ActiveRecord::Migration
  def change
    change_table :bikes do |t|
      t.change_comment :name, "anon: lorem_word"
      t.change_comment :serial_number, "anon: ugcid"
      t.change_comment :owner_email, "anon: email"
      t.change_comment :cached_data, "anon: lorem_sentence"
      t.change_comment :description, "anon: lorem_sentence"
      t.change_comment :pdf, "anon: lorem_word"
      t.change_comment :serial_normalized, "anon: ugcid"
      t.change_comment :all_description, "anon: ugcid"
      t.change_comment :stolen_lat, "anon: latitude"
      t.change_comment :stolen_long, "anon: longitude"
    end
  end
end
