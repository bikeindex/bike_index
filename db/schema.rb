# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140301174242) do

  create_table "b_params", :force => true do |t|
    t.text     "params"
    t.string   "bike_title"
    t.integer  "creator_id"
    t.integer  "created_bike_id"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
    t.integer  "bike_token_id"
    t.text     "bike_errors"
  end

  create_table "bike_token_invitations", :force => true do |t|
    t.text     "subject",          :default => "Bike Index? Awesome!"
    t.text     "message",          :default => "I just sent you a free bike registration."
    t.integer  "bike_token_count", :default => 1
    t.integer  "inviter_id"
    t.integer  "invitee_id"
    t.integer  "organization_id"
    t.string   "invitee_name"
    t.string   "invitee_email"
    t.boolean  "redeemed"
    t.datetime "created_at",                                                                :null => false
    t.datetime "updated_at",                                                                :null => false
  end

  create_table "bike_tokens", :force => true do |t|
    t.integer  "user_id"
    t.integer  "bike_id"
    t.datetime "used_at"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
    t.integer  "organization_id"
  end

  create_table "bikes", :force => true do |t|
    t.string   "name"
    t.integer  "cycle_type_id"
    t.string   "serial_number",                               :null => false
    t.string   "frame_model"
    t.integer  "manufacturer_id"
    t.boolean  "rear_tire_narrow",         :default => true
    t.integer  "frame_material_id"
    t.integer  "number_of_seats"
    t.integer  "propulsion_type_id"
    t.integer  "creation_organization_id"
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
    t.boolean  "stolen",                   :default => false, :null => false
    t.string   "propulsion_type_other"
    t.string   "manufacturer_other"
    t.string   "zipcode"
    t.text     "cached_data"
    t.text     "description"
    t.text     "owner_email"
    t.string   "thumb_path"
    t.text     "video_embed"
    t.integer  "year"
    t.boolean  "has_no_serial",            :default => false, :null => false
    t.integer  "creator_id"
    t.boolean  "created_with_token",       :default => false, :null => false
    t.integer  "location_id"
    t.boolean  "front_tire_narrow"
    t.integer  "primary_frame_color_id"
    t.integer  "secondary_frame_color_id"
    t.integer  "tertiary_frame_color_id"
    t.integer  "handlebar_type_id"
    t.string   "handlebar_type_other"
    t.integer  "front_wheel_size_id"
    t.integer  "rear_wheel_size_id"
    t.integer  "rear_gear_type_id"
    t.integer  "front_gear_type_id"
    t.boolean  "verified"
    t.boolean  "paid_for"
    t.text     "cached_attributes"
    t.string   "additional_registration"
    t.boolean  "belt_drive",               :default => false, :null => false
    t.boolean  "coaster_brake",            :default => false, :null => false
    t.string   "frame_size"
    t.string   "frame_size_unit"
    t.string   "serial_normalized"
    t.string   "pdf"
    t.integer  "card_id"
    t.boolean  "recovered",                :default => false, :null => false
    t.integer  "paint_id"
    t.boolean  "registered_new"
    t.boolean  "example",                  :default => false, :null => false
    t.string   "creation_zipcode"
    t.integer  "creation_country_id"
    t.integer  "country_id"
    t.string   "stock_photo_url"
  end

  add_index "bikes", ["creation_organization_id"], :name => "index_bikes_on_organization_id"

  create_table "blogs", :force => true do |t|
    t.text     "title"
    t.string   "title_slug"
    t.text     "body"
    t.text     "body_abbr"
    t.integer  "user_id"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.datetime "published_at"
    t.string   "tags"
    t.boolean  "published"
    t.string   "old_title_slug"
    t.text     "description_abbr"
  end

  create_table "cgroups", :force => true do |t|
    t.string   "name"
    t.string   "slug"
    t.string   "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "colors", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer  "priority"
  end

  create_table "components", :force => true do |t|
    t.string   "model_name"
    t.integer  "year"
    t.text     "description"
    t.integer  "manufacturer_id"
    t.integer  "ctype_id"
    t.string   "ctype_other"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
    t.integer  "bike_id"
    t.boolean  "front"
    t.boolean  "rear"
    t.string   "manufacturer_other"
    t.string   "serial_number"
  end

  create_table "countries", :force => true do |t|
    t.string   "name"
    t.string   "iso"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "ctypes", :force => true do |t|
    t.string   "name"
    t.string   "slug"
    t.string   "secondary_name"
    t.string   "image"
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
    t.boolean  "has_multiple",   :default => false, :null => false
    t.integer  "cgroup_id"
  end

  create_table "cycle_types", :force => true do |t|
    t.string   "name"
    t.string   "slug"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "feedbacks", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "title"
    t.text     "body"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.string   "feedback_type"
  end

  create_table "flavor_texts", :force => true do |t|
    t.string   "message"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "frame_materials", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string   "slug"
  end

  create_table "front_gear_types", :force => true do |t|
    t.string   "name"
    t.integer  "count"
    t.boolean  "internal",   :default => false, :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "standard"
  end

  create_table "handlebar_types", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string   "slug"
  end

  create_table "integrations", :force => true do |t|
    t.integer  "user_id"
    t.string   "access_token"
    t.string   "provider_name"
    t.text     "information"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  create_table "locations", :force => true do |t|
    t.integer  "organization_id"
    t.string   "zipcode"
    t.string   "city"
    t.string   "street"
    t.string   "phone"
    t.string   "email"
    t.string   "name"
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.datetime "deleted_at"
    t.boolean  "shown",           :default => false
    t.integer  "country_id"
    t.integer  "state_id"
  end

  create_table "lock_types", :force => true do |t|
    t.string   "name"
    t.string   "slug"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "locks", :force => true do |t|
    t.integer  "lock_type_id",       :default => 1
    t.boolean  "has_key",            :default => true
    t.boolean  "has_combination"
    t.string   "combination"
    t.string   "key_serial"
    t.integer  "manufacturer_id"
    t.string   "manufacturer_other"
    t.integer  "user_id"
    t.string   "lock_model"
    t.text     "notes"
    t.datetime "created_at",                           :null => false
    t.datetime "updated_at",                           :null => false
  end

  add_index "locks", ["user_id"], :name => "index_locks_on_user_id"

  create_table "manufacturers", :force => true do |t|
    t.string   "name"
    t.string   "slug"
    t.string   "website"
    t.boolean  "frame_maker"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
    t.string   "total_years_active"
    t.text     "notes"
    t.integer  "open_year"
    t.integer  "close_year"
    t.string   "logo"
    t.text     "description"
  end

  create_table "memberships", :force => true do |t|
    t.integer  "organization_id",                       :null => false
    t.integer  "user_id"
    t.string   "role",            :default => "member", :null => false
    t.string   "invited_email"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.datetime "deleted_at"
  end

  add_index "memberships", ["organization_id"], :name => "index_memberships_on_organization_id"
  add_index "memberships", ["user_id"], :name => "index_memberships_on_user_id"

  create_table "normalized_serial_segments", :force => true do |t|
    t.string   "segment"
    t.integer  "bike_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "organization_deals", :force => true do |t|
    t.integer  "organization_id"
    t.string   "deal_name"
    t.string   "email"
    t.string   "user_id"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  create_table "organization_invitations", :force => true do |t|
    t.string   "invitee_email"
    t.string   "invitee_name"
    t.integer  "invitee_id"
    t.integer  "organization_id"
    t.integer  "inviter_id"
    t.boolean  "redeemed"
    t.string   "membership_role", :default => "member"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.datetime "deleted_at"
  end

  create_table "organizations", :force => true do |t|
    t.string   "name"
    t.string   "slug",                                           :null => false
    t.integer  "available_invitation_count", :default => 10
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at",                                     :null => false
    t.string   "website"
    t.string   "short_name"
    t.integer  "default_bike_token_count",   :default => 5,      :null => false
    t.boolean  "show_on_map"
    t.integer  "sent_invitation_count",      :default => 0
    t.datetime "deleted_at"
    t.boolean  "is_suspended",               :default => false,  :null => false
    t.integer  "auto_user_id"
    t.string   "org_type",                   :default => "shop", :null => false
    t.string   "access_token"
    t.text     "new_bike_notification"
  end

  add_index "organizations", ["slug"], :name => "index_organizations_on_slug", :unique => true

  create_table "ownerships", :force => true do |t|
    t.integer  "bike_id"
    t.integer  "user_id"
    t.string   "owner_email"
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
    t.integer  "creator_id"
    t.boolean  "current",     :default => false
    t.boolean  "claimed"
    t.boolean  "example",     :default => false, :null => false
  end

  create_table "paints", :force => true do |t|
    t.string   "name"
    t.integer  "color_id"
    t.integer  "manufacturer_id"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  create_table "propulsion_types", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "public_images", :force => true do |t|
    t.string   "image"
    t.string   "name"
    t.integer  "listing_order",  :default => 0
    t.integer  "imageable_id"
    t.string   "imageable_type"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

  add_index "public_images", ["imageable_id", "imageable_type"], :name => "index_public_images_on_imageable_id_and_imageable_type"

  create_table "rear_gear_types", :force => true do |t|
    t.string   "name"
    t.integer  "count"
    t.boolean  "internal",   :default => false, :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "standard"
  end

  create_table "states", :force => true do |t|
    t.string   "name"
    t.string   "abbreviation"
    t.integer  "country_id"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  create_table "stolen_notifications", :force => true do |t|
    t.string   "subject"
    t.text     "message"
    t.integer  "sender_id"
    t.integer  "receiver_id"
    t.integer  "bike_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "stolen_records", :force => true do |t|
    t.string   "zipcode"
    t.string   "city"
    t.text     "theft_description"
    t.text     "time"
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
    t.integer  "bike_id"
    t.boolean  "current",                  :default => true
    t.string   "street"
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "date_stolen"
    t.string   "phone"
    t.boolean  "phone_for_everyone"
    t.boolean  "phone_for_users",          :default => true
    t.boolean  "phone_for_shops",          :default => true
    t.boolean  "phone_for_police",         :default => true
    t.string   "police_report_number"
    t.string   "locking_description"
    t.string   "lock_defeat_description"
    t.integer  "country_id"
    t.string   "police_report_department"
    t.integer  "state_id"
    t.integer  "creation_organization_id"
  end

  create_table "users", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.text     "password"
    t.datetime "last_login"
    t.boolean  "superuser",                    :default => false, :null => false
    t.text     "password_reset_token"
    t.datetime "created_at",                                      :null => false
    t.datetime "updated_at",                                      :null => false
    t.string   "password_digest"
    t.boolean  "banned"
    t.string   "phone"
    t.string   "zipcode"
    t.string   "twitter"
    t.boolean  "show_twitter",                 :default => false, :null => false
    t.string   "website"
    t.boolean  "show_website",                 :default => false, :null => false
    t.boolean  "show_phone",                   :default => true
    t.boolean  "show_bikes",                   :default => false, :null => false
    t.string   "username"
    t.boolean  "has_stolen_bikes"
    t.string   "avatar"
    t.text     "description"
    t.text     "title"
    t.boolean  "terms_of_service",             :default => false, :null => false
    t.boolean  "vendor_terms_of_service"
    t.datetime "when_vendor_terms_of_service"
    t.boolean  "confirmed"
    t.string   "confirmation_token"
    t.boolean  "can_invite"
  end

  add_index "users", ["password_reset_token"], :name => "index_users_on_password_reset_token"

  create_table "wheel_sizes", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.integer  "iso_bsd"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "priority"
  end

end
