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

ActiveRecord::Schema.define(version: 20170210192240) do

  create_table "companies", force: :cascade do |t|
    t.string   "name"
    t.integer  "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email"
    t.string   "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "voltron_notification_email_notifications", force: :cascade do |t|
    t.string  "to"
    t.string  "from"
    t.string  "subject"
    t.string  "template_path"
    t.string  "template_name"
    t.string  "mailer_class"
    t.string  "mailer_method"
    t.text    "request_json"
    t.text    "response_json"
    t.integer "notification_id"
  end

  create_table "voltron_notification_sms_notification_attachments", force: :cascade do |t|
    t.integer  "sms_notification_id"
    t.string   "attachment"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  create_table "voltron_notification_sms_notifications", force: :cascade do |t|
    t.string   "to"
    t.string   "from"
    t.text     "message"
    t.text     "request_json"
    t.text     "response_json"
    t.integer  "notification_id"
    t.string   "status"
    t.string   "sid"
    t.string   "error_code"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  create_table "voltron_notifications", force: :cascade do |t|
    t.string   "notifyable_type"
    t.integer  "notifyable_id"
    t.text     "request_json"
    t.text     "response_json"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

end
