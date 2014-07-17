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

ActiveRecord::Schema.define(version: 20140717090913) do

  create_table "accounts", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "amenities", force: true do |t|
    t.string   "name"
    t.integer  "remote_id"
    t.datetime "remote_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "remote_data"
  end

  create_table "locations", force: true do |t|
    t.string   "name"
    t.integer  "synced_id"
    t.datetime "synced_updated_at"
    t.text     "synced_data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "photos", force: true do |t|
    t.string   "filename"
    t.integer  "synced_id"
    t.integer  "location_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "rentals", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "synced_id"
    t.text     "synced_data"
    t.datetime "synced_updated_at"
    t.integer  "account_id"
  end

  add_index "rentals", ["synced_id"], name: "index_rentals_on_synced_id"

  create_table "synced_synchronizations", force: true do |t|
    t.string   "model"
    t.datetime "synchronized_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
