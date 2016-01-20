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

ActiveRecord::Schema.define(version: 20160113145914) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  add_index "accounts", ["authentication_token"], name: "index_accounts_on_authentication_token", unique: true, using: :btree
  add_index "accounts", ["email"], name: "index_accounts_on_email", unique: true, using: :btree
  add_index "accounts", ["reset_password_token"], name: "index_accounts_on_reset_password_token", unique: true, using: :btree

  create_table "application_histories", force: true do |t|
    t.integer  "application_id"
    t.string   "type"
    t.string   "version"
    t.string   "protocol"
    t.string   "url"
    t.string   "revision"
    t.text     "pre_deploy"
    t.text     "post_deploy"
    t.text     "parameters"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  create_table "applications", force: true do |t|
    t.integer  "system_id"
    t.string   "name"
    t.text     "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "domain"
  end

  create_table "assignment_roles", force: true do |t|
    t.integer  "assignment_id"
    t.integer  "role_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "assignment_roles", ["assignment_id", "role_id"], name: "index_assignment_roles_on_assignment_id_and_role_id", unique: true, using: :btree

  create_table "assignments", force: true do |t|
    t.integer  "project_id", null: false
    t.integer  "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "assignments", ["project_id", "account_id"], name: "index_assignments_on_project_id_and_account_id", unique: true, using: :btree

  create_table "base_images", force: true do |t|
    t.integer  "cloud_id"
    t.string   "source_image"
    t.string   "ssh_username"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "platform"
    t.string   "platform_version"
  end

  create_table "blueprint_histories", force: true do |t|
    t.integer  "blueprint_id",              null: false
    t.integer  "version",                   null: false
    t.string   "consul_secret_key"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.text     "encrypted_ssh_private_key"
  end

  create_table "blueprint_patterns", force: true do |t|
    t.integer  "blueprint_id",     null: false
    t.integer  "pattern_id",       null: false
    t.string   "revision"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "platform"
    t.string   "platform_version"
  end

  create_table "blueprints", force: true do |t|
    t.integer  "project_id"
    t.string   "name"
    t.text     "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
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
    t.text     "description"
    t.string   "type"
    t.string   "entry_point"
    t.string   "key"
    t.string   "encrypted_secret"
    t.string   "tenant_name"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "deployments", force: true do |t|
    t.integer  "environment_id"
    t.integer  "application_history_id"
    t.string   "status"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "environments", force: true do |t|
    t.integer  "system_id"
    t.string   "name"
    t.text     "description"
    t.string   "status"
    t.string   "ip_address"
    t.text     "platform_outputs"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.integer  "blueprint_history_id"
    t.text     "template_parameters"
  end

  create_table "images", force: true do |t|
    t.integer  "cloud_id"
    t.integer  "base_image_id"
    t.string   "name"
    t.string   "role"
    t.string   "image"
    t.text     "message"
    t.string   "status"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.integer  "pattern_snapshot_id"
  end

  create_table "pattern_snapshots", force: true do |t|
    t.integer  "blueprint_history_id", null: false
    t.string   "name"
    t.string   "type"
    t.string   "protocol"
    t.string   "url"
    t.string   "revision"
    t.text     "parameters"
    t.string   "roles"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.string   "platform"
    t.string   "platform_version"
    t.string   "providers"
  end

  create_table "patterns", force: true do |t|
    t.string   "name"
    t.string   "type"
    t.string   "protocol"
    t.string   "url"
    t.string   "revision"
    t.text     "parameters"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "project_id"
    t.string   "roles"
    t.string   "providers"
  end

  create_table "permissions", force: true do |t|
    t.integer  "role_id"
    t.string   "model"
    t.string   "action"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "permissions", ["role_id", "model", "action"], name: "index_permissions_on_role_id_and_model_and_action", unique: true, using: :btree

  create_table "projects", force: true do |t|
    t.string   "name",        null: false
    t.text     "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "roles", force: true do |t|
    t.integer  "project_id"
    t.string   "name"
    t.string   "description"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.boolean  "preset",      default: false, null: false
  end

  create_table "sessions", force: true do |t|
    t.string   "session_id", null: false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", unique: true, using: :btree
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree

  create_table "stacks", force: true do |t|
    t.integer  "environment_id"
    t.integer  "cloud_id"
    t.string   "name"
    t.string   "status"
    t.text     "template_parameters"
    t.text     "parameters"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.integer  "pattern_snapshot_id"
  end

  create_table "systems", force: true do |t|
    t.integer  "project_id"
    t.integer  "primary_environment_id"
    t.string   "name"
    t.text     "description"
    t.string   "domain"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

end
