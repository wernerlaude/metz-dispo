class CreateUnassignedDeliveryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :unassigned_delivery_items do |t|
      # Referenzen
      t.string :liefschnr, null: false
      t.integer :posnr, null: false
      t.integer :vauftragnr

      # Adressen
      t.integer :kund_adr_nr
      t.integer :werk_adr_nr
      t.text :loading_address_override
      t.text :unloading_address_override

      # Artikel-Daten
      t.string :artikel_nr, limit: 50
      t.string :bezeichnung, limit: 255
      t.decimal :menge, precision: 15, scale: 2
      t.decimal :gebinhalt, precision: 15, scale: 2
      t.string :einheit, limit: 20
      t.integer :typ, default: 0

      # Preise
      t.decimal :freight_price, precision: 15, scale: 2, default: 0.0
      t.decimal :loading_price, precision: 15, scale: 2, default: 0.0
      t.decimal :unloading_price, precision: 15, scale: 2, default: 0.0
      t.decimal :brutto, precision: 15, scale: 2

      # Fahrzeug
      t.string :vehicle_override, limit: 22
      t.integer :fahrzeugart_id
      t.string :kessel, limit: 50

      # Zeitdaten
      t.timestamp :beginn
      t.timestamp :ende
      t.date :planned_date
      t.time :planned_time

      # Kommentare
      t.text :kund_kommentar
      t.text :werk_kommentar
      t.text :planning_notes
      t.text :info

      # Positionen
      t.integer :kund_pos
      t.integer :werk_pos

      # Status
      t.string :status, limit: 20, null: false, default: 'draft'
      t.integer :gedruckt, default: 0

      # Weitere Felder
      t.string :art, limit: 30
      t.integer :plan_nr, default: 0
      t.string :kontrakt_nr, default: '0'
      t.string :tabelle_herkunft

      # Rechnungsfelder
      t.boolean :invoiced, null: false, default: false
      t.integer :invoice_number
      t.timestamp :invoiced_at

      t.timestamps
    end

    # Indices
    add_index :unassigned_delivery_items, [ :liefschnr, :posnr ], unique: true, name: 'idx_unassigned_items_position'
    add_index :unassigned_delivery_items, :status
    add_index :unassigned_delivery_items, :planned_date
    add_index :unassigned_delivery_items, :invoiced
    add_index :unassigned_delivery_items, :vauftragnr
    add_index :unassigned_delivery_items, :kund_adr_nr
    add_index :unassigned_delivery_items, :gedruckt
  end
end
