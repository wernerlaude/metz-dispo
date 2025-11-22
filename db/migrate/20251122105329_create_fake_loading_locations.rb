class CreateFakeLoadingLocations < ActiveRecord::Migration[8.0]
  def up
    # Füge kundennr Feld hinzu falls nicht vorhanden
    unless column_exists?(:loading_locations, :kundennr)
      add_column :loading_locations, :kundennr, :integer
    end

    unless index_exists?(:loading_locations, :kundennr)
      add_index :loading_locations, :kundennr, unique: true
    end

    # Erstelle Fake LoadingLocations für die benötigten Kundennummern
    locations = [
      { kundennr: 10016, werk_name: "Kunde 10016", address: "Musterstraße 1, 12345 Stadt" },
      { kundennr: 10022, werk_name: "Kunde 10022", address: "Beispielweg 2, 12345 Stadt" },
      { kundennr: 12057, werk_name: "Kunde 12057", address: "Testplatz 3, 12345 Stadt" },
      { kundennr: 12058, werk_name: "Kunde 12058", address: "Demogasse 4, 12345 Stadt" },
      { kundennr: 19456, werk_name: "Kunde 19456", address: "Probeallee 5, 12345 Stadt" },
      { kundennr: 10479, werk_name: "Kunde 10479", address: "Versuchsring 6, 12345 Stadt" },
      { kundennr: 15118, werk_name: "Kunde 15118", address: "Übungsstraße 7, 12345 Stadt" },
      { kundennr: 18925, werk_name: "Kunde 18925", address: "Trainingsweg 8, 12345 Stadt" },
      { kundennr: 14623, werk_name: "Kunde 14623", address: "Schulungspfad 9, 12345 Stadt" },
      { kundennr: 25649, werk_name: "Kunde 25649", address: "Lernplatz 10, 12345 Stadt" },
      { kundennr: 10626, werk_name: "Kunde 10626", address: "Kursallee 11, 12345 Stadt" },
      { kundennr: 18673, werk_name: "Kunde 18673", address: "Seminarweg 12, 12345 Stadt" }
    ]

    locations.each do |loc|
      # Hole nächste ID von der Sequence
      next_id = execute("SELECT nextval('loading_locations_id_seq')").first['nextval']

      execute <<-SQL
        INSERT INTO loading_locations (id, werk_name, address, kundennr, active, created_at, updated_at)
        VALUES (#{next_id}, '#{loc[:werk_name]}', '#{loc[:address]}', #{loc[:kundennr]}, true, NOW(), NOW())
        ON CONFLICT (kundennr) DO NOTHING;
      SQL
      puts "✓ Created: #{loc[:werk_name]} (ID: #{next_id}, Kundennr: #{loc[:kundennr]})"
    end
  end

  def down
    execute <<-SQL
      DELETE FROM loading_locations#{' '}
      WHERE werk_name LIKE 'Kunde %';
    SQL

    if index_exists?(:loading_locations, :kundennr)
      remove_index :loading_locations, :kundennr
    end

    if column_exists?(:loading_locations, :kundennr)
      remove_column :loading_locations, :kundennr
    end
  end
end
