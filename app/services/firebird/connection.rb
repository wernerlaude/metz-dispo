module Firebird
  class Connection
    def self.instance
      @instance ||= new
    end

    def initialize
      connect
    end

    def connect
      @db = Fb::Database.connect(
        database: ENV.fetch("FIREBIRD_DATABASE", 'L3:D:\\Landwehr\\LCS\\Datenbanken\\MAND6.FDB'),
        username: ENV.fetch("FIREBIRD_USERNAME", "SYSDBA"),
        password: ENV.fetch("FIREBIRD_PASSWORD", "jTGUYHWYHcIw8vfHedFvJ3tp"),
        charset: "UTF8"
      )
    rescue => e
      Rails.logger.error "Firebird connection error: #{e.message}"
      raise
    end

    def query(sql)
      reconnect_if_needed
      cursor = @db.execute(sql)
      field_names = cursor.fields.map { |f| f.name.strip }
      
      rows = []
      while row = cursor.fetch
        hash = {}
        field_names.each_with_index do |name, idx|
          value = row[idx]
          value = value.strip if value.is_a?(String)
          hash[name] = value
        end
        rows << hash
      end
      
      cursor.close
      rows
    rescue => e
      Rails.logger.error "Firebird query error: #{e.message}"
      raise
    end

    def execute_update(sql)
      reconnect_if_needed
      result = @db.execute(sql)
      result.close if result.respond_to?(:close)
      true
    rescue => e
      Rails.logger.error "Firebird execute_update error: #{e.message}"
      raise
    end

    def close
      @db&.close
      @db = nil
    end

    private

    def reconnect_if_needed
      connect unless @db
    rescue
      connect
    end
  end
end
