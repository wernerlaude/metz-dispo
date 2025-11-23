# lib/tasks/fix_delivery_positions.rake
namespace :fix do
  desc "Create missing DeliveryPositions from UnassignedDeliveryItems"
  task create_missing_positions: :environment do
    puts "🔍 Suche fehlende DeliveryPositions..."

    created = 0
    errors = 0

    UnassignedDeliveryItem.find_each do |item|
      # Prüfen ob DeliveryPosition existiert
      position = DeliveryPosition.find_by(
        liefschnr: item.liefschnr,
        posnr: item.posnr
      )

      if position
        # Position existiert bereits
        next
      end

      # DeliveryPosition erstellen
      begin
        DeliveryPosition.create!(
          liefschnr: item.liefschnr,
          posnr: item.posnr,
          artikelnr: item.artikel_nr || "UNKNOWN",
          bezeichn1: item.bezeichnung || "Importiert",
          bezeichn2: nil,
          liefmenge: item.menge || 0,
          einheit: item.einheit || "ST",
          tour_id: nil,
          sequence_number: nil
        )

        created += 1
        print "\r✓ Erstellt: #{created} | Fehler: #{errors}"

      rescue => e
        errors += 1
        puts "\n⚠️  Fehler bei #{item.liefschnr}-#{item.posnr}: #{e.message}"
      end
    end

    puts "\n\n✅ Fertig!"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "📊 Statistik:"
    puts "   Erstellt: #{created}"
    puts "   Fehler:   #{errors}"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  end
end