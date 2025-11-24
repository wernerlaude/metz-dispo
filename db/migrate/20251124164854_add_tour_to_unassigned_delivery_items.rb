class AddTourToUnassignedDeliveryItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :unassigned_delivery_items, :tour, null: true, foreign_key: true
    add_column :unassigned_delivery_items, :sequence_number, :integer
  end
end
