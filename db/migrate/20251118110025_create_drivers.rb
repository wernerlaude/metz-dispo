class CreateDrivers < ActiveRecord::Migration[8.0]
  def change
    create_table :drivers, force: :cascade do |t|
      t.string :first_name
      t.string :last_name
      t.string :pin
      t.integer :vehicle_id
      t.integer :trailer_id
      t.integer :tablet_id
      t.boolean :active
      t.integer :driver_type

      t.timestamps
    end
  end
end
