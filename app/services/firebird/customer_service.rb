module Firebird
  class CustomerService
    def initialize
      @connection = Firebird::Connection.instance
    end

    def all
      rows = @connection.query("SELECT * FROM WWS_KUNDEN1 ORDER BY KUNDENNR")
      rows.map { |row| Customer.from_firebird_row(row) }
    end

    def find(kundennr)
      rows = @connection.query("SELECT * FROM WWS_KUNDEN1 WHERE KUNDENNR = #{kundennr}")
      return nil if rows.empty?

      Customer.from_firebird_row(rows.first)
    end

    def update(kundennr, attributes)
      updates = []
      updates << "KUNDGRUPPE = #{attributes[:kundgruppe]}" if attributes[:kundgruppe]
      updates << "RABATT = #{attributes[:rabatt]}" if attributes[:rabatt]
      updates << "ZAHLUNGART = '#{escape_sql(attributes[:zahlungart])}'" if attributes[:zahlungart]
      updates << "UMSATZSTEUER = '#{escape_sql(attributes[:umsatzsteuer])}'" if attributes[:umsatzsteuer]
      updates << "GEKUENDIGT = '#{escape_sql(attributes[:gekuendigt])}'" if attributes[:gekuendigt]

      return false if updates.empty?

      sql = "UPDATE WWS_KUNDEN1 SET #{updates.join(', ')} WHERE KUNDENNR = #{kundennr}"
      @connection.execute_update(sql)
      true
    end

    private

    def escape_sql(value)
      return "" if value.nil?
      value.to_s.gsub("'", "''")
    end
  end
end
