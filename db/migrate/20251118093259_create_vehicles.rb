class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table "vehicles", force: :cascade do |t|
      t.string :license_plate
      t.string :vehicle_number
      t.string :vehicle_type

      t.timestamps
    end
  end
end
