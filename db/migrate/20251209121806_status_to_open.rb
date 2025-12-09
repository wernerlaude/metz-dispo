class StatusToOpen < ActiveRecord::Migration[8.0]
  def up
    # Alle draft und ready Status auf open umstellen
    execute <<-SQL
      UPDATE unassigned_delivery_items#{' '}
      SET status = 'open'#{' '}
      WHERE status IN ('draft', 'ready')
    SQL
  end

  def down
    # Zurück auf ready (da wir nicht wissen was draft war)
    execute <<-SQL
      UPDATE unassigned_delivery_items#{' '}
      SET status = 'ready'#{' '}
      WHERE status = 'open'
    SQL
  end
end
