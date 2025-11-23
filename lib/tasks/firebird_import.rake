# lib/tasks/firebird_import.rake
namespace :firebird do
  desc "Import addresses from Firebird to PostgreSQL (Development only)"
  task import_addresses: :environment do
    unless Rails.env.development?
      puts "❌ This task should only run in development!"
      exit
    end

    puts "🔌 Connecting to Firebird API..."
    puts "📍 API: #{ENV.fetch('FIREBIRD_API_URL', 'http://192.168.33.61:8080/api/v1')}"
    puts ""

    begin
      # Adressen über API holen
      response = FirebirdConnectApi.get("/addresses")

      unless response.success?
        puts "❌ API Error: #{response.code}"
        puts response.body
        exit
      end

      data = JSON.parse(response.body)
      firebird_addresses = data["data"] || []

      if firebird_addresses.empty?
        puts "⚠️  Keine Adressen gefunden!"
        exit
      end

      puts "✅ Connected successfully!"
      puts "📋 Gefunden: #{firebird_addresses.count} Adressen\n\n"

      imported = 0
      updated = 0
      skipped = 0
      errors = 0

      firebird_addresses.each do |fb_addr|
        begin
          nummer = fb_addr["address_number"]

          unless nummer
            skipped += 1
            next
          end

          # Address in Dev-DB finden oder erstellen
          address = Address.find_or_initialize_by(nummer: nummer)

          was_new = address.new_record?

          address.assign_attributes(
            name1: fb_addr["name_1"]&.strip,
            name2: fb_addr["name_2"]&.strip,
            strasse: fb_addr["street"]&.strip,
            plz: fb_addr["postal_code"]&.strip,
            ort: fb_addr["city"]&.strip,
            land: fb_addr["country"]&.strip,
            art: "KUNDE", # Default, da nicht in API
            email: fb_addr["email"]&.strip,
            knr: nil # KNR ist nicht in der Address-API
          )

          # Validierung temporär deaktivieren für Import
          if address.save(validate: false)
            if was_new
              imported += 1
            else
              updated += 1 if address.previous_changes.any?
            end
          else
            errors += 1
            puts "\n⚠️  Fehler für Adresse #{nummer}: #{address.errors.full_messages.join(', ')}"
          end

          total = imported + updated + skipped + errors
          print "\r📦 Verarbeitet: #{total}/#{firebird_addresses.count} | Neu: #{imported} | Aktualisiert: #{updated} | Übersprungen: #{skipped} | Fehler: #{errors}"

        rescue => e
          errors += 1
          puts "\n⚠️  Exception: #{e.message}"
          puts e.backtrace.first(3).join("\n")
        end
      end

      puts "\n\n✅ Import abgeschlossen!"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "📊 Statistik:"
      puts "   Gesamt:         #{firebird_addresses.count}"
      puts "   Neu importiert: #{imported}"
      puts "   Aktualisiert:   #{updated}"
      puts "   Übersprungen:   #{skipped}"
      puts "   Fehler:         #{errors}"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    rescue => e
      puts "\n❌ Import Fehler: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Clear all imported addresses from development database"
  task clear_addresses: :environment do
    unless Rails.env.development?
      puts "❌ This task should only run in development!"
      exit
    end

    count = Address.count

    if count.zero?
      puts "ℹ️  Keine Adressen zum Löschen vorhanden"
      exit
    end

    print "⚠️  Wirklich #{count} Adressen aus Development-DB löschen? (y/N): "
    answer = STDIN.gets.chomp

    if answer.downcase == "y"
      Address.delete_all
      puts "✅ #{count} Adressen gelöscht"
    else
      puts "❌ Abgebrochen"
    end
  end

  desc "Show Firebird API connection test"
  task test_connection: :environment do
    puts "Testing Firebird API connection..."
    puts "URL: #{ENV.fetch('FIREBIRD_API_URL', 'http://192.168.33.61:8080/api/v1')}"

    response = FirebirdConnectApi.get("/addresses")

    if response.success?
      data = JSON.parse(response.body)
      addresses = data["data"] || []

      puts "✅ Connection successful!"
      puts "📊 Found #{addresses.count} addresses"

      if addresses.any?
        first = addresses.first
        puts "\n📝 Sample address:"
        puts "   Nummer: #{first['address_number']}"
        puts "   Name:   #{first['name_1']}"
        puts "   Straße: #{first['street']}"
        puts "   Ort:    #{first['postal_code']} #{first['city']}"
      end
    else
      puts "❌ Connection failed!"
      puts "Status: #{response.code}"
      puts response.body
    end
  end
end
