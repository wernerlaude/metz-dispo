module Firebird
  class SalesOrderService
    def initialize
      @connection = Firebird::Connection.instance
    end

    def all
      rows = @connection.query("SELECT * FROM WWS_VERKAUF1 ORDER BY VAUFTRAGNR DESC")
      rows.map { |row| SalesOrder.from_firebird_row(row) }
    end

    def find(vauftragnr)
      rows = @connection.query("SELECT * FROM WWS_VERKAUF1 WHERE VAUFTRAGNR = #{vauftragnr}")
      return nil if rows.empty?
      
      SalesOrder.from_firebird_row(rows.first)
    end

    def find_with_items(vauftragnr)
      sales_order = find(vauftragnr)
      return nil unless sales_order

      items = get_items(vauftragnr)
      
      {
        sales_order: sales_order.as_json,
        items: items.map(&:as_json)
      }
    end

    def get_items(vauftragnr)
      rows = @connection.query("SELECT * FROM WWS_VERKAUF2 WHERE VAUFTRAGNR = #{vauftragnr} ORDER BY POSNR")
      rows.map { |row| SalesOrderItem.from_firebird_row(row) }
    end

    def update(vauftragnr, attributes)
      updates = []
      updates << "GEPLLIEFDATUM = '#{attributes[:geplliefdatum]}'" if attributes[:geplliefdatum]
      updates << "LIEFERTEXT = '#{escape_sql(attributes[:liefertext])}'" if attributes[:liefertext]
      updates << "OBJEKT = '#{escape_sql(attributes[:objekt])}'" if attributes[:objekt]
      updates << "AUFTSTATUS = '#{escape_sql(attributes[:auftstatus])}'" if attributes[:auftstatus]

      return false if updates.empty?

      sql = "UPDATE WWS_VERKAUF1 SET #{updates.join(', ')} WHERE VAUFTRAGNR = #{vauftragnr}"
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
