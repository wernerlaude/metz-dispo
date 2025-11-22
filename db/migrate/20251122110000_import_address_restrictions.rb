class ImportAddressRestrictions < ActiveRecord::Migration[8.0]
  def up
    # Importiere mit Kundennummern
    execute <<-SQL
      INSERT INTO address_restrictions (driver_id, liefadrnr, reason)
      SELECT DISTINCT t.driver_id, t.liefadrnr, 'Importiert'
      FROM (VALUES
        (5, 10016), (5, 10022), (6, 12057), (6, 12058),
        (8, 19456), (8, 10479), (30, 10016), (30, 10022),
        (30, 15118), (5, 18925), (60, 14623), (65, 25649),
        (5, 10626), (5, 18673)
      ) AS t(driver_id, liefadrnr)
      WHERE EXISTS (SELECT 1 FROM drivers WHERE id = t.driver_id)
        AND EXISTS (SELECT 1 FROM loading_locations WHERE kundennr = t.liefadrnr)
        AND NOT EXISTS (
          SELECT 1 FROM address_restrictions#{' '}
          WHERE driver_id = t.driver_id AND liefadrnr = t.liefadrnr
        );
    SQL
  end

  def down
    execute "DELETE FROM address_restrictions WHERE reason = 'Importiert';"
  end
end
