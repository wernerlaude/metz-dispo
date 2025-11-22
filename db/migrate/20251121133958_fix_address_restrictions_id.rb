class FixAddressRestrictionsId < ActiveRecord::Migration[8.0]
    def up
      # Finde die höchste ID
      max_id = execute("SELECT MAX(id) FROM address_restrictions").first['max']
      max_id = max_id.to_i + 1 if max_id

      # Erstelle oder setze die Sequence zurück
      execute <<-SQL
      -- Erstelle Sequence falls sie nicht existiert
      CREATE SEQUENCE IF NOT EXISTS address_restrictions_id_seq;

      -- Setze die Sequence auf den nächsten Wert
      SELECT setval('address_restrictions_id_seq', #{max_id || 1}, false);

      -- Setze den Default-Wert für id
      ALTER TABLE address_restrictions#{' '}
        ALTER COLUMN id SET DEFAULT nextval('address_restrictions_id_seq');
    SQL
    end

    def down
      execute <<-SQL
      ALTER TABLE address_restrictions#{' '}
        ALTER COLUMN id DROP DEFAULT;
    SQL
    end
end
