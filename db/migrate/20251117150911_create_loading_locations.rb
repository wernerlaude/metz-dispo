class CreateLoadingLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :loading_locations do |t|
      t.string :name, null: false
      t.text :address
      t.string :contact_person
      t.string :phone
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :loading_locations, :name
    add_index :loading_locations, :active
  end
end
