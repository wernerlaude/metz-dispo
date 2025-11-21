class FixAddressRestrictionsId < ActiveRecord::Migration[8.0]
  def up
    # Füge id als Serial Primary Key hinzu
    execute <<-SQL
      ALTER TABLE address_restrictions DROP COLUMN IF EXISTS id;
      ALTER TABLE address_restrictions ADD COLUMN id SERIAL PRIMARY KEY;
    SQL
  end

  def down
    execute "ALTER TABLE address_restrictions DROP COLUMN id"
  end
end
