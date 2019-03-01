class AddsCommentsForAnonymization < ActiveRecord::Migration
  def change
    # - skipped
    # change_table :ads 
    # change_table :bike_organizations
    # change_table :blogs
    # change_table :cgroups
    # change_table :colors


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
      t.change_comment :thumb_path, "anon: url"
    end

    change_table :b_params do |t|
      t.change_comment :email, "anon: email"
      t.change_comment :params, "anon: empty_curly"
      t.change_comment :old_params, "anon: empty_string"
      t.change_comment :id_token, "anon: md5"
      t.change_comment :image, "anon: lorem_word"
      t.change_comment :image_temp, "anon: lorem_word"
      t.change_comment :bike_errors, "anon: lorem_sentence"
    end

    change_table :bike_codes do |t|
      t.change_comment :code, "anon: ugcid"
    end

    change_table :bulk_imports do |t|
      t.change_comment :file, "anon: lorem_word"
    end
  end
end
