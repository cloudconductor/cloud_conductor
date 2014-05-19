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

ActiveRecord::Schema.define(version: 20140516013558) do

  create_table "clouds", force: true do |t|
    t.string   "name"
    t.string   "cloud_type"
    t.string   "cloud_entry_point_url"
    t.string   "key"
    t.string   "secret"
    t.string   "tenant_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "systems", force: true do |t|
    t.string   "name"
    t.text     "template_body"
    t.string   "template_url"
    t.text     "parameters"
    t.integer  "primary_cloud_id"
    t.integer  "secondary_cloud_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
