module Firebird
  class DeliveryNoteService
    def initialize
      @connection = Firebird::Connection.instance
    end

    def all
      rows = @connection.query("SELECT * FROM WWS_VLIEFER1 ORDER BY LIEFSCHNR DESC")
      rows.map { |row| DeliveryNote.from_firebird_row(row) }
    end

    def find(liefschnr)
      rows = @connection.query("SELECT * FROM WWS_VLIEFER1 WHERE LIEFSCHNR = #{liefschnr}")
      return nil if rows.empty?
      
      DeliveryNote.from_firebird_row(rows.first)
    end

    def find_with_items(liefschnr)
      delivery_note = find(liefschnr)
      return nil unless delivery_note

      items = get_items(liefschnr)
      
      {
        delivery_note: delivery_note.as_json,
        items: items.map(&:as_json)
      }
    end

    def get_items(liefschnr)
      rows = @connection.query("SELECT * FROM WWS_VLIEFER2 WHERE LIEFSCHNR = #{liefschnr} ORDER BY POSNR")
      rows.map { |row| DeliveryNoteItem.from_firebird_row(row) }
    end

    def update(liefschnr, attributes)
      updates = []
      updates << "LKWNR = #{attributes[:lkwnr]}" if attributes[:lkwnr]
      updates << "GEPLLIEFDATUM = '#{attributes[:geplliefdatum]}'" if attributes[:geplliefdatum]

      return false if updates.empty?

      sql = "UPDATE WWS_VLIEFER1 SET #{updates.join(', ')} WHERE LIEFSCHNR = #{liefschnr}"
      @connection.execute_update(sql)
      true
    end

    def update_item(liefschnr, posnr, attributes)
      updates = []
      updates << "LIEFMENGE = #{attributes[:liefmenge]}" if attributes[:liefmenge]

      return false if updates.empty?

      sql = "UPDATE WWS_VLIEFER2 SET #{updates.join(', ')} WHERE LIEFSCHNR = #{liefschnr} AND POSNR = #{posnr}"
      @connection.execute_update(sql)
      true
    end

    private

    def escape_sql(value)
      return '' if value.nil?
      value.to_s.gsub("'", "''")
    end
  end
end
