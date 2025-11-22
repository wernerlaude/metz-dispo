class FixTrailersPrimaryKey < ActiveRecord::Migration[8.0]
  def up
    # Stelle sicher, dass id eine Sequence hat
    execute <<-SQL
      -- Erstelle Sequence falls nicht vorhanden
      CREATE SEQUENCE IF NOT EXISTS trailers_id_seq;
      
      -- Setze Sequence auf höchsten Wert + 1
      SELECT setval('trailers_id_seq', 
                    COALESCE((SELECT MAX(id) FROM trailers), 0) + 1, 
                    false);
      
      -- Setze Default für id Spalte
      ALTER TABLE trailers 
        ALTER COLUMN id SET DEFAULT nextval('trailers_id_seq');
      
      -- Stelle sicher, dass id Primary Key ist
      ALTER TABLE trailers 
        DROP CONSTRAINT IF EXISTS trailers_pkey;
      
      ALTER TABLE trailers 
        ADD PRIMARY KEY (id);
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE trailers 
        ALTER COLUMN id DROP DEFAULT;
    SQL
  end
end