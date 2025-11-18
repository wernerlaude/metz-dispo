class CreateAddressRestrictions < ActiveRecord::Migration[8.0]
  def change
    create_table :address_restrictions, id: false, force: :cascade do |t|
      t.integer "id"
      t.integer "driver_id"
      t.integer "adresses_id"
    end

    # create_table :address_restrictions do |t|
    # t.references :driver, null: false, foreign_key: true
    # t.references :addresses, null: false, foreign_key: true
    # t.string :reason  # optional, falls du einen Grund speichern willst
    # t.timestamps
    # end

    # add_index :address_restrictions, [:driver_id, :nummer], unique: true
  end
end
