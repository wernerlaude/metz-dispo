module Firebird
  class AddressService
    def initialize
      @connection = Firebird::Connection.instance
    end

    def all
      rows = @connection.query("SELECT * FROM ADRESSEN ORDER BY NUMMER")
      rows.map { |row| Address.from_firebird_row(row) }
    end

    def find(nummer)
      rows = @connection.query("SELECT * FROM ADRESSEN WHERE NUMMER = #{nummer}")
      return nil if rows.empty?
      
      Address.from_firebird_row(rows.first)
    end

    def update(nummer, attributes)
      updates = []
      updates << "NAME1 = '#{escape_sql(attributes[:name1])}'" if attributes[:name1]
      updates << "NAME2 = '#{escape_sql(attributes[:name2])}'" if attributes[:name2]
      updates << "STRASSE = '#{escape_sql(attributes[:strasse])}'" if attributes[:strasse]
      updates << "PLZ = '#{escape_sql(attributes[:plz])}'" if attributes[:plz]
      updates << "ORT = '#{escape_sql(attributes[:ort])}'" if attributes[:ort]
      updates << "LAND = '#{escape_sql(attributes[:land])}'" if attributes[:land]
      updates << "TELEFON1 = '#{escape_sql(attributes[:telefon1])}'" if attributes[:telefon1]
      updates << "TELEFON2 = '#{escape_sql(attributes[:telefon2])}'" if attributes[:telefon2]
      updates << "TELEFAX = '#{escape_sql(attributes[:telefax])}'" if attributes[:telefax]
      updates << "EMAIL = '#{escape_sql(attributes[:email])}'" if attributes[:email]
      updates << "HOMEPAGE = '#{escape_sql(attributes[:homepage])}'" if attributes[:homepage]
      updates << "ANREDE = '#{escape_sql(attributes[:anrede])}'" if attributes[:anrede]
      updates << "BRIEFANR = '#{escape_sql(attributes[:briefanr])}'" if attributes[:briefanr]

      return false if updates.empty?

      sql = "UPDATE ADRESSEN SET #{updates.join(', ')} WHERE NUMMER = #{nummer}"
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
