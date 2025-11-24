# db/seeds/development_test_data.rb
if Rails.env.development?
  puts "Creating test delivery items..."

  test_items = [
    { liefschnr: "TEST001", posnr: 10, kundname: "Regens Wagner Absberg", bezeichn1: "BIO Roggen", menge: 25, einheit: "TO", ladeort: "Dittenheim" },
    { liefschnr: "TEST001", posnr: 20, kundname: "Regens Wagner Absberg", bezeichn1: "BIO Weizen", menge: 15, einheit: "TO", ladeort: "Dittenheim" },
    { liefschnr: "TEST002", posnr: 10, kundname: "Meraner Mühle", bezeichn1: "Dinkel", menge: 30, einheit: "TO", ladeort: "Gunzenhausen" },
    { liefschnr: "TEST003", posnr: 10, kundname: "Bäckerei Schmidt", bezeichn1: "Weizenmehl Type 550", menge: 500, einheit: "KG", ladeort: "Dittenheim" },
    { liefschnr: "TEST003", posnr: 20, kundname: "Bäckerei Schmidt", bezeichn1: "Roggenmehl Type 1150", menge: 300, einheit: "KG", ladeort: "Dittenheim" },
    { liefschnr: "TEST004", posnr: 10, kundname: "Landhandel Meyer", bezeichn1: "Futtermittel Mix", menge: 20, einheit: "TO", ladeort: "Gunzenhausen" },
    { liefschnr: "TEST005", posnr: 10, kundname: "Genossenschaft Franken", bezeichn1: "Hafer", menge: 18, einheit: "TO", ladeort: "Dittenheim" },
    { liefschnr: "TEST006", posnr: 10, kundname: "Mühle Altmühltal", bezeichn1: "Gerste", menge: 22, einheit: "TO", ladeort: "Gunzenhausen" }
  ]

  test_items.each do |item_data|
    UnassignedDeliveryItem.find_or_create_by!(
      liefschnr: item_data[:liefschnr],
      posnr: item_data[:posnr]
    ) do |item|
      item.kundname = item_data[:kundname]
      item.bezeichn1 = item_data[:bezeichn1]
      item.menge = item_data[:menge]
      item.einheit = item_data[:einheit]
      item.ladeort = item_data[:ladeort]
      item.status = "ready"
      item.tabelle_herkunft = "manual"
      item.geplliefdatum = Date.current + rand(1..7).days
      item.kundennr = rand(100000..999999)
      item.liefadrnr = rand(1..100)
      item.kundadrnr = rand(1..100)
    end
  end

  puts "✓ Created #{UnassignedDeliveryItem.count} test delivery items"
end
