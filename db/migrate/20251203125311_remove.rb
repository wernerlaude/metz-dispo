class Remove < ActiveRecord::Migration[8.0]
  def up
    # Nicht benötigte Spalten entfernen
    remove_column :unassigned_delivery_items, :freight_price
    remove_column :unassigned_delivery_items, :loading_price
    remove_column :unassigned_delivery_items, :unloading_price
    remove_column :unassigned_delivery_items, :vehicle_override

    # Timestamps entfernen und neu hinzufügen (kommen dann ans Ende)
    remove_column :unassigned_delivery_items, :created_at
    remove_column :unassigned_delivery_items, :updated_at
    add_timestamps :unassigned_delivery_items, null: false, default: -> { 'NOW()' }
  end

  def down
    # Timestamps zurück (Position egal bei Rollback)
    # created_at/updated_at existieren bereits durch add_timestamps

    # Spalten wieder hinzufügen
    add_column :unassigned_delivery_items, :vehicle_override, :string, limit: 22
    add_column :unassigned_delivery_items, :unloading_price, :decimal, precision: 15, scale: 2, default: 0.0
    add_column :unassigned_delivery_items, :loading_price, :decimal, precision: 15, scale: 2, default: 0.0
    add_column :unassigned_delivery_items, :freight_price, :decimal, precision: 15, scale: 2, default: 0.0
  end
end
