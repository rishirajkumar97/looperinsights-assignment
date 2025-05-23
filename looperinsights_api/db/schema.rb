# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_05_23_184759) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "countries", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "timezone", null: false
    t.index ["code", "timezone", "name"], name: "index_countries_on_code_and_timezone_and_name", unique: true
    t.index ["name"], name: "index_countries_on_name"
  end

  create_table "episodes", force: :cascade do |t|
    t.string "name", null: false
    t.integer "season", null: false
    t.integer "number"
    t.string "type", null: false
    t.integer "runtime"
    t.date "airdate", null: false
    t.datetime "airstamp", null: false
    t.string "official_site"
    t.float "avg_rating"
    t.text "summary"
    t.string "image_original_url"
    t.string "image_medium_url"
    t.bigint "show_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["airdate"], name: "index_episodes_on_airdate"
    t.index ["avg_rating"], name: "index_episodes_on_avg_rating"
    t.index ["name"], name: "index_episodes_on_name"
    t.index ["show_id"], name: "index_episodes_on_show_id"
    t.index ["type"], name: "index_episodes_on_type"
  end

  create_table "networks", force: :cascade do |t|
    t.string "name", null: false
    t.integer "country_id", null: false
    t.string "official_site"
    t.index ["name"], name: "index_networks_on_name"
  end

  create_table "raw_tvdata", force: :cascade do |t|
    t.jsonb "raw_data"
    t.integer "status", default: 0
    t.integer "retry_count", default: 0
  end

  create_table "shows", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.string "type", null: false
    t.string "language"
    t.string "status"
    t.integer "runtime"
    t.integer "avg_runtime"
    t.date "premiered"
    t.date "ended"
    t.string "official_site"
    t.float "avg_rating"
    t.jsonb "schedule"
    t.string "imdb_id"
    t.integer "thetvdb_id"
    t.integer "tvrage_id"
    t.text "summary"
    t.datetime "updated"
    t.bigint "lastaired_episode_id"
    t.bigint "upcoming_episode_id"
    t.string "image_original_url"
    t.string "image_medium_url"
    t.text "genres", default: [], array: true
    t.bigint "network_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "web_channel_id"
    t.index ["imdb_id"], name: "index_shows_on_imdb_id", unique: true, where: "(imdb_id IS NOT NULL)"
    t.index ["name"], name: "index_shows_on_name"
    t.index ["network_id"], name: "index_shows_on_network_id"
    t.index ["premiered"], name: "index_shows_on_premiered"
    t.index ["status"], name: "index_shows_on_status"
    t.index ["thetvdb_id"], name: "index_shows_on_thetvdb_id", unique: true, where: "(thetvdb_id IS NOT NULL)"
    t.index ["tvrage_id"], name: "index_shows_on_tvrage_id", unique: true, where: "(tvrage_id IS NOT NULL)"
    t.index ["type"], name: "index_shows_on_type"
    t.index ["updated"], name: "index_shows_on_updated"
    t.index ["url"], name: "index_shows_on_url", unique: true
  end

  create_table "web_channels", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "country_id"
    t.string "official_site"
    t.index ["name"], name: "index_web_channels_on_name"
  end
end
