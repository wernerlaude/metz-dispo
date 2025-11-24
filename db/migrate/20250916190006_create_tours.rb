class CreateTours < ActiveRecord::Migration[8.0]
  def change
    create_table "tours", force: :cascade do |t|
      t.string "name", null: false
      t.date "tour_date", null: false
      t.integer "vehicle_id"
      t.integer "trailer_id"
      t.bigint "driver_id"
      t.bigint "loading_location_id"
      t.text "notes"
      t.integer "total_positions", default: 0
      t.boolean "completed", default: false, null: false
      t.string "delivery_type", limit: 10
      t.integer "tour_type", limit: 2, default: 0, null: false
      t.time "departure_time"
      t.datetime "departure_at"
      t.datetime "arrival_at"
      t.boolean "sent", default: false, null: false
      t.string "carrier", limit: 255
      t.float "km_start"
      t.float "km_end"
      t.decimal "total_weight", precision: 10, scale: 2, default: "0.0"
      t.decimal "fuel_start", precision: 10, scale: 2
      t.decimal "fuel_end", precision: 10, scale: 2
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false

      # Indizes
      t.index [ "name", "tour_date" ], name: "index_tours_on_name_and_tour_date", unique: true
      t.index [ "tour_date" ], name: "index_tours_on_tour_date"
      t.index [ "tour_date", "vehicle_id" ], name: "index_tours_on_tour_date_and_vehicle_id"
      t.index [ "vehicle_id" ], name: "index_tours_on_vehicle_id"
      t.index [ "trailer_id" ], name: "index_tours_on_trailer_id"
      t.index [ "driver_id" ], name: "index_tours_on_driver_id"
      t.index [ "loading_location_id" ], name: "index_tours_on_loading_location_id"
      t.index [ "completed" ], name: "index_tours_on_completed"
      t.index [ "sent" ], name: "index_tours_on_sent"
    end
  end
end
