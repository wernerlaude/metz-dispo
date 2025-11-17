class CreateTours < ActiveRecord::Migration[8.1]
  def change
    # Tours Tabelle erstellen
    create_table :tours do |t|
      t.string :name, null: false
      t.date :tour_date, null: false
      t.string :vehicle, null: true
      t.references :driver, null: true, foreign_key: true
      t.references :loading_location, null: true, foreign_key: true
      t.text :notes
      t.decimal :total_weight, precision: 10, scale: 2, default: 0
      t.integer :total_positions, default: 0
      t.timestamps
    end

    # Indices für Tours
    add_index :tours, :tour_date unless index_exists?(:tours, :tour_date)
    add_index :tours, :vehicle unless index_exists?(:tours, :vehicle)
    add_index :tours, [ :tour_date, :vehicle ] unless index_exists?(:tours, [ :tour_date, :vehicle ])
    add_index :tours, :driver_id unless index_exists?(:tours, :driver_id)
    add_index :tours, :loading_location_id unless index_exists?(:tours, :loading_location_id)
    add_index :tours, [ :name, :tour_date ], unique: true unless index_exists?(:tours, [ :name, :tour_date ])

    # Tour-Beziehung zu DeliveryPositions hinzufügen
    unless column_exists?(:wws_vliefer2, :tour_id)
      add_column :wws_vliefer2, :tour_id, :bigint, null: true
    end

    unless column_exists?(:wws_vliefer2, :sequence_number)
      add_column :wws_vliefer2, :sequence_number, :integer, null: true
    end

    # Indices für DeliveryPositions
    add_index :wws_vliefer2, :tour_id unless index_exists?(:wws_vliefer2, :tour_id)
    add_index :wws_vliefer2, [ :tour_id, :sequence_number ] unless index_exists?(:wws_vliefer2, [ :tour_id, :sequence_number ])

    unless index_exists?(:wws_vliefer2, [ :tour_id, :sequence_number ], name: 'index_delivery_positions_on_tour_and_sequence')
      add_index :wws_vliefer2, [ :tour_id, :sequence_number ], unique: true,
                name: 'index_delivery_positions_on_tour_and_sequence'
    end

    # Foreign Key Constraint OHNE zu validieren (erlaubt bestehende "verwaiste" Daten)
    unless foreign_key_exists?(:wws_vliefer2, :tours)
      add_foreign_key :wws_vliefer2, :tours, column: :tour_id, validate: false
    end
  end
end
