class FixLoadingLocationsPrimaryKey < ActiveRecord::Migration[8.0]
  def up
    # Falls id existiert aber nicht PRIMARY KEY ist
    execute <<-SQL
      ALTER TABLE loading_locations#{' '}
      DROP CONSTRAINT IF EXISTS loading_locations_pkey;

      ALTER TABLE loading_locations#{' '}
      ADD PRIMARY KEY (id);
    SQL
  end

  def down
    execute "ALTER TABLE loading_locations DROP CONSTRAINT IF EXISTS loading_locations_pkey"
  end
end
