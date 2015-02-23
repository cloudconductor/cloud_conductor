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

ActiveRecord::Schema.define(version: 20150212004325) do

  create_table "accounts", force: true do |t|
    t.string   "email",                  default: "",    null: false
    t.string   "encrypted_password",     default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "authentication_token"
    t.string   "name",                   default: "",    null: false
    t.boolean  "admin",                  default: false, null: false
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
  end

  add_index "accounts", ["authentication_token"], name: "index_accounts_on_authentication_token", unique: true
  add_index "accounts", ["email"], name: "index_accounts_on_email", unique: true
  add_index "accounts", ["reset_password_token"], name: "index_accounts_on_reset_password_token", unique: true

  create_table "application_histories", force: true do |t|
    t.integer  "application_id"
    t.string   "domain"
    t.string   "type"
    t.string   "version"
    t.string   "protocol"
    t.string   "url"
    t.string   "revision"
    t.string   "pre_deploy"
    t.string   "post_deploy"
    t.string   "parameters"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  create_table "applications", force: true do |t|
    t.integer  "system_id"
    t.string   "name"
    t.string   "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "assignments", force: true do |t|
    t.integer  "project_id",             null: false
    t.integer  "account_id",             null: false
    t.integer  "role",       default: 1
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "assignments", ["project_id", "account_id"], name: "index_assignments_on_project_id_and_account_id", unique: true

  create_table "base_images", force: true do |t|
    t.integer  "cloud_id"
    t.string   "os"
    t.string   "source_image"
    t.string   "ssh_username"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "blueprints", force: true do |t|
    t.integer  "project_id"
    t.string   "name"
    t.string   "description"
    t.integer  "version"
    t.string   "consul_secret_key"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  create_table "candidates", force: true do |t|
    t.integer  "cloud_id"
    t.integer  "environment_id"
    t.integer  "priority"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  create_table "clouds", force: true do |t|
    t.integer  "project_id"
    t.string   "name"
    t.string   "description"
    t.string   "type"
    t.string   "entry_point"
    t.string   "key"
    t.string   "secret"
    t.string   "tenant_name"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "deployments", force: true do |t|
    t.integer  "environment_id"
    t.integer  "application_history_id"
    t.string   "status"
    t.string   "event"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "environments", force: true do |t|
    t.integer  "system_id"
    t.integer  "blueprint_id"
    t.string   "name"
    t.string   "description"
    t.string   "status"
    t.string   "ip_address"
    t.text     "template_parameters"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  create_table "images", force: true do |t|
    t.integer  "pattern_id"
    t.integer  "cloud_id"
    t.integer  "base_image_id"
    t.string   "name"
    t.string   "role"
    t.string   "image"
    t.string   "message"
    t.string   "status"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "patterns", force: true do |t|
    t.integer  "blueprint_id"
    t.string   "name"
    t.string   "type"
    t.string   "protocol"
    t.string   "url"
    t.string   "revision"
    t.text     "parameters"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "projects", force: true do |t|
    t.string   "name",        null: false
    t.string   "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "stacks", force: true do |t|
    t.integer  "environment_id"
    t.integer  "pattern_id"
    t.integer  "cloud_id"
    t.string   "name"
    t.string   "status"
    t.text     "template_parameters"
    t.text     "parameters"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.text     "instance_sizes"
  end

  create_table "systems", force: true do |t|
    t.integer  "project_id"
    t.integer  "primary_environment_id"
    t.string   "name"
    t.string   "description"
    t.string   "domain"
    t.string   "monitoring_host"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

end
