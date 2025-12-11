class CreateGeocodeCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :geocode_caches do |t|
      t.string :address_hash, null: false
      t.string :address_string, null: false
      t.decimal :lat, precision: 10, scale: 7
      t.decimal :lng, precision: 10, scale: 7
      t.string :source, default: 'nominatim'
      t.boolean :found, default: false

      t.timestamps
    end

    add_index :geocode_caches, :address_hash, unique: true
  end
end
