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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170831101909) do

  create_table "accounts", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "amenities", force: :cascade do |t|
    t.string   "name"
    t.integer  "remote_id"
    t.datetime "remote_updated_at"
    t.text     "remote_data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "bookings", force: :cascade do |t|
    t.string   "name"
    t.datetime "synced_all_at"
    t.integer  "synced_id"
    t.text     "synced_data"
    t.integer  "account_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "reviews_count"
  end

  create_table "clients", force: :cascade do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.integer  "synced_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "destinations", force: :cascade do |t|
    t.string   "name"
    t.integer  "location_id"
    t.integer  "synced_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "location_translations", force: :cascade do |t|
    t.integer  "location_id", null: false
    t.string   "locale",      null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "name"
  end

  add_index "location_translations", ["locale"], name: "index_location_translations_on_locale"
  add_index "location_translations", ["location_id"], name: "index_location_translations_on_location_id"

  create_table "locations", force: :cascade do |t|
    t.string   "name"
    t.integer  "synced_id"
    t.text     "synced_data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "los_records", force: :cascade do |t|
    t.integer  "account_id"
    t.integer  "synced_id"
    t.integer  "rate"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "los_records", ["account_id"], name: "index_los_records_on_account_id"
  add_index "los_records", ["synced_id"], name: "index_los_records_on_synced_id"

  create_table "periods", force: :cascade do |t|
    t.string   "start_date"
    t.string   "end_date"
    t.integer  "rental_id"
    t.integer  "synced_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "synced_all_at"
  end

  create_table "photos", force: :cascade do |t|
    t.string   "filename"
    t.integer  "synced_id"
    t.integer  "location_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "canceled_at"
  end

  create_table "rental_aliases", force: :cascade do |t|
    t.string   "name"
    t.integer  "synced_id"
    t.text     "synced_data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "rental_aliases", ["synced_id"], name: "index_rental_aliases_on_synced_id"

  create_table "rentals", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "synced_id"
    t.text     "synced_data"
    t.integer  "account_id"
  end

  add_index "rentals", ["synced_id"], name: "index_rentals_on_synced_id"

  create_table "synced_timestamps", force: :cascade do |t|
    t.integer  "parent_scope_id"
    t.string   "parent_scope_type"
    t.string   "model_class",       null: false
    t.datetime "synced_at",         null: false
  end

  add_index "synced_timestamps", ["parent_scope_id", "parent_scope_type", "synced_at"], name: "synced_timestamps_max_index"

end
