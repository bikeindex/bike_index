class AddsCommentsForAnonymization < ActiveRecord::Migration
  def change
    # - skipped
    # change_table :ads 
    # change_table :bike_organizations
    # change_table :blogs
    # change_table :cgroups
    # change_table :colors
    # change_table :components
    # change_table :creation_states
    # change_table :ctypes
    # change_table :cycle_types
    # change_table :ctypes
    # change_table :duplicate_bike_groups
    # change_table :exports
    # change_table :flavor_texts
    # change_table :frame_materials
    # change_table :front_gear_types
    # change_table :handlebar_types
    # change_table :invoice_paid_features
    # change_table :listicles
    # change_table :lock_types
    # change_table :locks
    # change_table :mail_snippets
    # change_table :manufacturers
    # change_table :memberships
    # change_table :other_listings
    # *confirm change_table :paid_features
    # change_table :paints
    # change_table :propulsion_types
    # *confirm change_table :public_images
    # change_table :rear_gear_types
    # change_table :recovery_displays
    # change_table :schema_migrations
    # change_table :states
    # change_table :recovery_displays
    # change_table :tweets
    # change_table :wheel_sizes

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
      t.change_comment :image_tmp, "anon: lorem_word"
      t.change_comment :bike_errors, "anon: lorem_sentence"
    end

    change_table :bike_codes do |t|
      t.change_comment :code, "anon: ugcid"
    end

    change_table :bulk_imports do |t|
      t.change_comment :file, "anon: lorem_word"
    end

    change_table :customer_contacts do |t|
      t.change_comment :user_email, "anon: email"
      t.change_comment :creator_email, "anon: email"
      t.change_comment :info_hash, "anon: empty_string"
    end

    change_table :feedbacks do |t|
      t.change_comment :name, "anon: full_name"
      t.change_comment :email, "anon: email"
      t.change_comment :title, "anon: lorem_word"
      t.change_comment :body, "anon: lorem_sentence"
    end

    change_table :integrations do |t|
      t.change_comment :access_token, "anon: md5"
      t.change_comment :information, "anon: empty_string"
    end

    change_table :invoices do |t|
      t.change_comment :notes, "anon: lorem_sentence"
      # TODO: t.change_comment :amount_paid_cents, "anon: number" 
    end

    change_table :locations do |t|
      t.change_comment :latitude, "anon: latitude"
      t.change_comment :longitude, "anon: longitude"
      t.change_comment :name, "anon: company_name"
    end

    change_table :locks do |t|
      t.change_comment :key_serial, "anon: ugcid"
      t.change_comment :notes, "anon: lorem_sentence"
    end

    change_table :normalized_serial_segments do |t|
      t.change_comment :segment, "anon: ugcid"
    end

    change_table :oauth_access_grants do |t|
      t.change_comment :token, "anon: md5"
      t.change_comment :redirect_uri, "anon: url"
    end

    change_table :oauth_access_tokens do |t|
      t.change_comment :token, "anon: md5"
      t.change_comment :refresh_token, "anon: md5"
    end

    change_table :oauth_applications do |t|
      t.change_comment :name, "anon: company_name"
      t.change_comment :uid, "anon: md5"
      t.change_comment :secret, "anon: md5"
      t.change_comment :redirect_uri, "anon: url"
    end

    change_table :organization_invitations do |t|
      t.change_comment :invitee_email, "anon: email"
      t.change_comment :invitee_name, "anon: full_name"
    end

    change_table :organization_messages do |t|
      t.change_comment :email, "anon: email"
      t.change_comment :body, "anon: lorem_sentence"
      t.change_comment :address, "anon: address_line_1"
      t.change_comment :latitude, "anon: latitude"
      t.change_comment :longitude, "anon: longitude"
    end  
    
    change_table :organizations do |t|
      t.change_comment :slug, "anon: lorem_word"
      t.change_comment :name, "anon: company_name"
      t.change_comment :short_name, "anon: lorem_word"
      t.change_comment :website, "anon: url"
      t.change_comment :access_token, "anon: md5"
    end

    change_table :ownerships do |t|
      t.change_comment :owner_email, "anon: email"
    end

    change_table :payments do |t|
      t.change_comment :stripe_id, "anon: md5"
      t.change_comment :email, "anon: email"
    end

    change_table :stolen_notifications do |t|
      t.change_comment :message, "anon: lorem_sentence"
      t.change_comment :receiver_email, "anon: email"
      t.change_comment :reference_url, "anon: url"
      t.change_comment :receiver_email, "anon: email"
    end

    change_table :stolen_records do |t|
      t.change_comment :latitude, "anon: latitude"
      t.change_comment :longitude, "anon: longitude"
      t.change_comment :phone, "anon: phone_number"
      t.change_comment :secondary_phone, "anon: phone_number"
      t.change_comment :street, "anon: address_line_1"
      t.change_comment :police_report_number, "anon: ugcid"
    end

    change_table :user_emails do |t|
      t.change_comment :email, "anon: email"
    end    

    change_table :users do |t|
      t.change_comment :name, "anon: full_name"
      t.change_comment :email, "anon: email"
      t.change_comment :password, "anon: password"
      t.change_comment :password_digest, "anon: bcrypt_password"
      t.change_comment :website, "anon: url"
      t.change_comment :twitter, "anon: url"
      t.change_comment :username, "anon: lorem_word"
      t.change_comment :description, "anon: lorem_sentence"
      t.change_comment :title, "anon: lorem_word"
      t.change_comment :confirmation_token, "anon: md5"
      t.change_comment :auth_token, "anon: md5"
      t.change_comment :stripe_id, "anon: md5"
      t.change_comment :paid_membership_info, "anon: empty_string"
      t.change_comment :my_bikes_hash, "anon: empty_string"
      t.change_comment :partner_data, "anon: empty_curly"
      t.change_comment :latitude, "anon: latitude"
      t.change_comment :longitude, "anon: longitude"
      t.change_comment :street, "anon: address_line_1"
      t.change_comment :city, "anon: address_city"
      t.change_comment :phone, "anon: phone_number"
    end   
  end
end
