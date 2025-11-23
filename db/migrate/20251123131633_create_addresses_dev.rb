# db/migrate/[timestamp]_create_addresses_dev.rb
class CreateAddressesDev < ActiveRecord::Migration[8.0]
  def change
    # Nur in Development ausführen
    return unless Rails.env.development?

    create_table :addresses_dev do |t|
      t.integer :nummer, null: false, index: { unique: true }
      t.string :name1
      t.string :name2
      t.string :strasse
      t.string :plz, limit: 5
      t.string :ort
      t.string :land
      t.string :art
      t.string :email
      t.integer :knr

      t.timestamps
    end

    add_index :addresses_dev, :art
    add_index :addresses_dev, :plz
    add_index :addresses_dev, :ort
    add_index :addresses_dev, :knr
  end
end
