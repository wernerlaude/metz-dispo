class CreateDrivers < ActiveRecord::Migration[8.1]
  def change
    create_table :drivers do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :pin, null: false
      t.integer :vehicle_id, default: 0
      t.integer :trailer_id, default: 0
      t.integer :tablet_id, default: 0
      t.boolean :active, default: true, null: false
      t.integer :driver_type, default: 0, null: false

      t.timestamps
    end

    add_index :drivers, :pin, unique: true
    add_index :drivers, :active
    add_index :drivers, :driver_type
  end
end
