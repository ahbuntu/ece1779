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

ActiveRecord::Schema.define(version: 20150225230108) do

  create_table "auto_scales", force: :cascade do |t|
    t.float    "grow_cpu_thresh"
    t.float    "shrink_cpu_thresh"
    t.float    "grow_ratio_thresh"
    t.float    "shrink_ratio_thresh"
    t.integer  "enabled",                    limit: 1
    t.integer  "cooldown_period_in_seconds", limit: 11, default: 0
    t.datetime "cooldown_expires_at"
    t.integer  "max_instances",              limit: 11, default: 10
  end

  create_table "images", force: :cascade do |t|
    t.integer "userId",            limit: 11
    t.string  "key1",              limit: 255
    t.string  "key2",              limit: 255
    t.string  "key3",              limit: 255
    t.string  "key4",              limit: 255
    t.string  "original_filename", limit: 255
    t.string  "uuid",              limit: 36
    t.string  "extension",         limit: 10
  end

  create_table "users", force: :cascade do |t|
    t.string "login",    limit: 255, null: false
    t.string "password", limit: 255, null: false
  end

end
