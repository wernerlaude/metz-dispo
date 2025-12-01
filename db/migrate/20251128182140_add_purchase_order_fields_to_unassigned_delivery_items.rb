class AddPurchaseOrderFieldsToUnassignedDeliveryItems < ActiveRecord::Migration[8.0]
  def change
    add_column :unassigned_delivery_items, :bestellnr, :string
    add_column :unassigned_delivery_items, :lieferantnr, :integer
    add_column :unassigned_delivery_items, :liefname, :string

    add_index :unassigned_delivery_items, :bestellnr
  end
end
