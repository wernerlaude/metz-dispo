# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_21_133958) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "Spedion_Auftrag", id: :serial, force: :cascade do |t|
    t.integer "KundAdrNr"
    t.integer "WerkAdrNr"
    t.integer "AuftrNr"
    t.integer "PosNr"
    t.string "LiefschNr", limit: 255
    t.integer "Menge"
    t.integer "Gebinhalt"
    t.string "Einheit", limit: 20
    t.integer "ProdNr"
    t.string "Preis", limit: 15
    t.string "Brutto", limit: 15
    t.string "Kessel", limit: 50
    t.datetime "Beginn", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "Ende", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "kundKommentar", limit: 45
    t.string "werkKommentar", limit: 45
    t.integer "kundPos"
    t.integer "werkPos"
    t.integer "idTour"
    t.integer "idFahrzeugart"
    t.string "Art", limit: 30
    t.integer "PlanNr", default: 0, null: false
    t.string "KontraktNr", limit: 255, default: "0", null: false
    t.text "Info"
    t.integer "Typ", null: false
    t.string "Tabelle_Herkunft", limit: 255, null: false
    t.integer "Gedruckt", default: 0, null: false
  end

  create_table "Spedion_Fahrer", id: :serial, force: :cascade do |t|
    t.string "Vorname", limit: 45, null: false
    t.string "Nachname", limit: 45, null: false
    t.string "Pin", limit: 45, null: false
    t.integer "idFahrzeug", default: 0, null: false
    t.integer "idHaenger", default: 0, null: false
    t.integer "idTablet", default: 0, null: false
    t.integer "Aktiv", default: 1, null: false
    t.integer "Art", default: 0, null: false
  end

  create_table "Spedion_Fahrzeug", id: false, force: :cascade do |t|
    t.integer "id"
    t.string "Kennzeichen", limit: 45
    t.string "Fahrzeugnr", limit: 45
    t.integer "Art"
  end

  create_table "Spedion_Haenger", id: false, force: :cascade do |t|
    t.integer "id"
    t.string "kennzeichen", limit: 45
    t.integer "art"
  end

  create_table "Spedion_Lademittel", id: false, force: :cascade do |t|
    t.integer "id"
    t.integer "Kundennr"
    t.integer "Auftrnr"
    t.integer "Datum"
    t.integer "Palette_plus"
    t.integer "Palette_minus"
    t.integer "Container_plus"
    t.integer "Container_minus"
  end

  create_table "Spedion_Tour", id: :serial, force: :cascade do |t|
    t.integer "idFahrzeug", null: false
    t.integer "idFahrer", null: false
    t.integer "idHaenger"
    t.boolean "Erledigt", default: false, null: false
    t.string "Lieferart", limit: 10, default: ""
    t.datetime "Erstellt", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.date "Datum", null: false
    t.time "Uhrzeit", null: false
    t.boolean "gesendet", default: false, null: false
    t.string "Spedition", limit: 255, null: false
    t.datetime "Abfahrt", precision: nil
    t.datetime "Ankunft", precision: nil
    t.float "Kilometer_Start", limit: 24
    t.float "Kilometer_Ende", limit: 24
    t.float "Diesel_Start"
    t.float "Diesel_Ende"
    t.integer "Typ", limit: 2, null: false
  end

  create_table "Sperrliste_Fahrer", id: false, force: :cascade do |t|
    t.integer "id"
    t.integer "idFahrer"
    t.integer "AdrNr"
  end

  create_table "address_restrictions", id: :serial, force: :cascade do |t|
    t.integer "driver_id"
    t.integer "liefadrnr"
  end

  create_table "adressen", primary_key: "nummer", id: :string, force: :cascade do |t|
    t.string "name1"
    t.string "name2"
    t.string "branche"
    t.string "strasse"
    t.string "nat"
    t.string "plz"
    t.string "ort"
    t.string "postfach"
    t.string "postfplz"
    t.string "postfort"
    t.string "land"
    t.string "telefon1"
    t.string "telefon2"
    t.string "telefax"
    t.string "email"
    t.string "homepage"
    t.string "art"
    t.string "knr"
    t.string "anrede"
    t.string "briefanr"
    t.string "lname1"
    t.string "lname2"
    t.string "lbranche"
    t.string "frei1"
    t.string "frei2"
    t.string "frei3"
    t.string "frei4"
    t.string "repl_id"
    t.string "repl_database"
    t.string "trfield"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["knr"], name: "index_adressen_on_knr"
    t.index ["nummer"], name: "index_adressen_on_nummer", unique: true
  end

  create_table "drivers", id: :serial, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "pin"
    t.integer "vehicle_id"
    t.integer "trailer_id"
    t.integer "tablet_id"
    t.boolean "active"
    t.integer "driver_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "loading_locations", force: :cascade do |t|
    t.string "name", null: false
    t.text "address"
    t.string "contact_person"
    t.string "phone"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_loading_locations_on_active"
    t.index ["name"], name: "index_loading_locations_on_name"
  end

  create_table "loading_locations_clone", id: false, force: :cascade do |t|
    t.bigint "id"
    t.string "name"
    t.text "address"
    t.string "contact_person"
    t.string "phone"
    t.boolean "active"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "orders", force: :cascade do |t|
    t.integer "kund_adr_nr"
    t.integer "werk_adr_nr"
    t.integer "auftr_nr"
    t.integer "pos_nr"
    t.string "liefsch_nr"
    t.integer "menge"
    t.integer "gebinhalt"
    t.string "einheit", limit: 20
    t.integer "prod_nr"
    t.string "preis", limit: 15
    t.string "brutto", limit: 15
    t.string "kessel", limit: 50
    t.datetime "beginn", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "ende", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "kund_kommentar", limit: 45
    t.string "werk_kommentar", limit: 45
    t.integer "kund_pos"
    t.integer "werk_pos"
    t.integer "id_tour"
    t.integer "id_fahrzeugart"
    t.string "art", limit: 30
    t.integer "plan_nr", default: 0, null: false
    t.string "kontrakt_nr", default: "0", null: false
    t.text "info"
    t.integer "typ", limit: 2, null: false, comment: "Sackware=0 Lose Ware=1"
    t.string "tabelle_herkunft", null: false
    t.integer "gedruckt", default: 0, null: false
    t.index ["id_tour"], name: "fk_spedion_place_spedion_tour1_idx"
  end

  create_table "sperrliste_fahrer", id: false, force: :cascade do |t|
    t.integer "id", null: false
    t.integer "driver_id", null: false
    t.integer "liefadrnr", null: false
  end

  create_table "tours", force: :cascade do |t|
    t.string "name", null: false
    t.date "tour_date", null: false
    t.integer "vehicle_id"
    t.integer "trailer_id"
    t.bigint "driver_id"
    t.bigint "loading_location_id"
    t.text "notes"
    t.integer "total_positions", default: 0
    t.boolean "completed", default: false, null: false
    t.string "delivery_type", limit: 10
    t.integer "tour_type", limit: 2, default: 0, null: false
    t.time "departure_time"
    t.datetime "departure_at"
    t.datetime "arrival_at"
    t.boolean "sent", default: false, null: false
    t.string "carrier", limit: 255
    t.float "km_start"
    t.float "km_end"
    t.decimal "total_weight", precision: 10, scale: 2, default: "0.0"
    t.decimal "fuel_start", precision: 10, scale: 2
    t.decimal "fuel_end", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_tours_on_completed"
    t.index ["driver_id"], name: "index_tours_on_driver_id"
    t.index ["loading_location_id"], name: "index_tours_on_loading_location_id"
    t.index ["name", "tour_date"], name: "index_tours_on_name_and_tour_date", unique: true
    t.index ["sent"], name: "index_tours_on_sent"
    t.index ["tour_date", "vehicle_id"], name: "index_tours_on_tour_date_and_vehicle_id"
    t.index ["tour_date"], name: "index_tours_on_tour_date"
    t.index ["trailer_id"], name: "index_tours_on_trailer_id"
    t.index ["vehicle_id"], name: "index_tours_on_vehicle_id"
  end

  create_table "trailers", id: :integer, default: nil, force: :cascade do |t|
    t.string "license_plate", limit: 45
    t.integer "art"
  end

  create_table "unassigned_delivery_items", force: :cascade do |t|
    t.string "liefschnr", null: false
    t.integer "posnr", null: false
    t.integer "vauftragnr"
    t.integer "kund_adr_nr"
    t.integer "werk_adr_nr"
    t.text "loading_address_override"
    t.text "unloading_address_override"
    t.string "artikel_nr", limit: 50
    t.string "bezeichnung", limit: 255
    t.decimal "menge", precision: 15, scale: 2
    t.decimal "gebinhalt", precision: 15, scale: 2
    t.string "einheit", limit: 20
    t.integer "typ", default: 0
    t.decimal "freight_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "loading_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "unloading_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "brutto", precision: 15, scale: 2
    t.string "vehicle_override", limit: 22
    t.integer "fahrzeugart_id"
    t.string "kessel", limit: 50
    t.datetime "beginn", precision: nil
    t.datetime "ende", precision: nil
    t.date "planned_date"
    t.time "planned_time"
    t.text "kund_kommentar"
    t.text "werk_kommentar"
    t.text "planning_notes"
    t.text "info"
    t.integer "kund_pos"
    t.integer "werk_pos"
    t.string "status", limit: 20, default: "draft", null: false
    t.integer "gedruckt", default: 0
    t.string "art", limit: 30
    t.integer "plan_nr", default: 0
    t.string "kontrakt_nr", default: "0"
    t.string "tabelle_herkunft"
    t.boolean "invoiced", default: false, null: false
    t.integer "invoice_number"
    t.datetime "invoiced_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gedruckt"], name: "index_unassigned_delivery_items_on_gedruckt"
    t.index ["invoiced"], name: "index_unassigned_delivery_items_on_invoiced"
    t.index ["kund_adr_nr"], name: "index_unassigned_delivery_items_on_kund_adr_nr"
    t.index ["liefschnr", "posnr"], name: "idx_unassigned_items_position", unique: true
    t.index ["planned_date"], name: "index_unassigned_delivery_items_on_planned_date"
    t.index ["status"], name: "index_unassigned_delivery_items_on_status"
    t.index ["vauftragnr"], name: "index_unassigned_delivery_items_on_vauftragnr"
  end

  create_table "unassigned_delivery_items_clone", id: false, force: :cascade do |t|
    t.bigint "id"
    t.string "liefschnr"
    t.integer "posnr"
    t.integer "vauftragnr"
    t.integer "kund_adr_nr"
    t.integer "werk_adr_nr"
    t.text "loading_address_override"
    t.text "unloading_address_override"
    t.string "artikel_nr", limit: 50
    t.string "bezeichnung", limit: 255
    t.decimal "menge", precision: 15, scale: 2
    t.decimal "gebinhalt", precision: 15, scale: 2
    t.string "einheit", limit: 20
    t.integer "typ"
    t.decimal "freight_price", precision: 15, scale: 2
    t.decimal "loading_price", precision: 15, scale: 2
    t.decimal "unloading_price", precision: 15, scale: 2
    t.decimal "brutto", precision: 15, scale: 2
    t.string "vehicle_override", limit: 22
    t.integer "fahrzeugart_id"
    t.string "kessel", limit: 50
    t.datetime "beginn"
    t.datetime "ende"
    t.date "planned_date"
    t.time "planned_time"
    t.text "kund_kommentar"
    t.text "werk_kommentar"
    t.text "planning_notes"
    t.text "info"
    t.integer "kund_pos"
    t.integer "werk_pos"
    t.string "status", limit: 20
    t.integer "gedruckt"
    t.string "art", limit: 30
    t.integer "plan_nr"
    t.string "kontrakt_nr", limit: 255
    t.string "tabelle_herkunft", limit: 255
    t.boolean "invoiced"
    t.integer "invoice_number"
    t.datetime "invoiced_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "customer_name"
    t.string "delivery_address_name"
    t.string "delivery_address_street"
    t.string "delivery_address_zip"
    t.string "delivery_address_city"
    t.text "delivery_address_full"
    t.integer "tour_id"
    t.integer "sequence_number"
  end

  create_table "vehicles", id: :bigint, default: nil, force: :cascade do |t|
    t.string "license_plate"
    t.string "vehicle_number"
    t.integer "vehicle_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "wws_kunden1", primary_key: "kundennr", id: :string, force: :cascade do |t|
    t.string "kundgruppe"
    t.string "bundesland"
    t.string "rechnkunde"
    t.string "umsatzsteuer"
    t.text "werbetext"
    t.string "rechnformular"
    t.decimal "rabatt", precision: 10, scale: 2
    t.string "zahlungart"
    t.string "zinstabsoll"
    t.string "zinstabhaben"
    t.decimal "zinssatzsoll", precision: 10, scale: 2
    t.decimal "zinssatzhaben", precision: 10, scale: 2
    t.boolean "zinsbuchung"
    t.decimal "selbstabhrabatt", precision: 10, scale: 2
    t.decimal "selbstabhbetrag", precision: 15, scale: 2
    t.boolean "bonusberecht"
    t.boolean "kontoauszug"
    t.date "datumlauszug"
    t.integer "nrlauszug"
    t.decimal "saldolauszug", precision: 15, scale: 2
    t.decimal "saldorechnung", precision: 15, scale: 2
    t.integer "lfdrechnnr"
    t.string "geschkonto"
    t.boolean "offeneposten"
    t.string "mitgliednr"
    t.boolean "gekuendigt"
    t.string "kuendgrund"
    t.date "datumeintritt"
    t.date "datumaustritt"
    t.integer "pflichtanteile"
    t.integer "pflichtanteilegez"
    t.string "edi_iln"
    t.string "edi_typ"
    t.string "edi_uebertrnr"
    t.string "edi_prefix"
    t.string "edi_kundennr"
    t.string "repl_id"
    t.string "repl_database"
    t.string "trfield"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["kundennr"], name: "index_wws_kunden1_on_kundennr", unique: true
    t.index ["kundgruppe"], name: "index_wws_kunden1_on_kundgruppe"
  end

  create_table "wws_verkauf1", primary_key: "vauftragnr", id: :string, force: :cascade do |t|
    t.date "datum"
    t.string "bediener"
    t.string "vertreter"
    t.string "kostenst"
    t.string "kundennr"
    t.string "debitorkto"
    t.string "kundname"
    t.string "kundadrnr"
    t.string "rechnadrnr"
    t.string "liefadrnr"
    t.string "gebiet"
    t.string "best_anrede"
    t.string "best_briefanrede"
    t.string "besteller"
    t.date "bestdatum"
    t.string "bestnrkd"
    t.string "kdabteilung"
    t.string "angebotnr"
    t.date "angebdatum"
    t.text "liefertext"
    t.string "objekt"
    t.string "lieferart"
    t.string "waehrcode"
    t.string "kundwaehrcode"
    t.string "mwstkz"
    t.integer "skonto1tg"
    t.decimal "skonto1pr", precision: 10, scale: 2
    t.integer "skonto2tg"
    t.decimal "skonto2pr", precision: 10, scale: 2
    t.integer "nettotg"
    t.integer "valuta"
    t.boolean "lastschrift"
    t.text "zahlbedtext"
    t.boolean "erledigt"
    t.string "auftstatus"
    t.boolean "auftrbestgedruckt"
    t.boolean "betrauftrgedruckt"
    t.string "geplliefjahrkw"
    t.date "geplliefdatum"
    t.string "verzgrund"
    t.string "lager"
    t.string "lkwnr"
    t.decimal "selbstabhrabatt", precision: 10, scale: 2
    t.string "spediteurnr"
    t.string "fahrzeug"
    t.string "containernr"
    t.string "transportart"
    t.string "ladeort"
    t.date "prodtermin"
    t.date "ladetermin"
    t.date "ladedatum"
    t.string "kfzkennzeichen1"
    t.string "kfzkennzeichen2"
    t.string "uhrzeit"
    t.text "infoallgemein"
    t.text "infoproduktion"
    t.text "infoverladung"
    t.text "infoliefsch"
    t.text "infoauftrbest"
    t.boolean "fremdwaehrung"
    t.decimal "umrfaktor", precision: 10, scale: 6
    t.boolean "bruttoberechn"
    t.datetime "geaendertam", precision: nil
    t.string "vertragstyp"
    t.string "versandart"
    t.string "repl_id"
    t.string "repl_database"
    t.string "trfield"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["datum"], name: "index_wws_verkauf1_on_datum"
    t.index ["kundennr"], name: "index_wws_verkauf1_on_kundennr"
    t.index ["vauftragnr"], name: "index_wws_verkauf1_on_vauftragnr", unique: true
  end

  create_table "wws_verkauf2", id: false, force: :cascade do |t|
    t.string "vauftragnr", null: false
    t.integer "posnr", null: false
    t.string "posart"
    t.string "artikelnr"
    t.string "bezeichn1"
    t.string "bezeichn2"
    t.text "langtext"
    t.string "artikelart"
    t.text "langzusaet"
    t.text "langliefer"
    t.text "langrechn"
    t.string "umsatzgrp"
    t.decimal "menge", precision: 15, scale: 6
    t.decimal "bishliefmg", precision: 15, scale: 6
    t.string "einhschl"
    t.string "einheit"
    t.string "preiseinh"
    t.decimal "gebindemg", precision: 15, scale: 6
    t.string "gebindschl"
    t.string "gebindeinh"
    t.decimal "gebinhalt", precision: 15, scale: 6
    t.decimal "listpreis", precision: 15, scale: 6
    t.decimal "listbrutto", precision: 15, scale: 6
    t.decimal "rabatt", precision: 10, scale: 2
    t.string "rabattart"
    t.decimal "einhpreis", precision: 15, scale: 6
    t.decimal "bruttpreis", precision: 15, scale: 6
    t.decimal "netto", precision: 15, scale: 2
    t.decimal "mwst", precision: 15, scale: 2
    t.decimal "brutto", precision: 15, scale: 2
    t.string "steuerschl"
    t.decimal "mwstsatz", precision: 10, scale: 2
    t.decimal "listpreis2", precision: 15, scale: 6
    t.decimal "listbrutto2", precision: 15, scale: 6
    t.decimal "einhpreis2", precision: 15, scale: 6
    t.decimal "bruttpreis2", precision: 15, scale: 6
    t.decimal "netto2", precision: 15, scale: 2
    t.decimal "mwst2", precision: 15, scale: 2
    t.decimal "brutto2", precision: 15, scale: 2
    t.decimal "rabatt2", precision: 10, scale: 2
    t.string "rabattart2"
    t.string "zuabschlagnr"
    t.string "zuabschlagnr2"
    t.string "lager"
    t.string "abteilung"
    t.string "lagerfach"
    t.string "chargennr"
    t.string "seriennr"
    t.decimal "gewicht", precision: 15, scale: 6
    t.decimal "ladungsgewicht", precision: 15, scale: 6
    t.string "palettennr"
    t.integer "palanzahl"
    t.string "rezepturnr"
    t.string "rezepturnr2"
    t.boolean "prod_erledigt"
    t.string "ruestliste"
    t.string "produktionsauftragid"
    t.string "prodanlage"
    t.string "vorprodanlage"
    t.string "repl_id"
    t.string "repl_database"
    t.string "trfield"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["artikelnr"], name: "index_wws_verkauf2_on_artikelnr"
    t.index ["vauftragnr", "posnr"], name: "index_wws_verkauf2_on_vauftragnr_and_posnr", unique: true
    t.index ["vauftragnr"], name: "index_wws_verkauf2_on_vauftragnr"
  end

  create_table "wws_vliefer1", primary_key: "liefschnr", id: :string, force: :cascade do |t|
    t.string "vauftragnr"
    t.string "rechnungnr"
    t.string "arechnungnr"
    t.date "datum"
    t.string "einkaufverkauf"
    t.string "bediener"
    t.string "vertreter"
    t.string "kostenst"
    t.string "kundennr"
    t.string "kundname"
    t.string "rechnadrnr"
    t.string "kundadrnr"
    t.string "liefadrnr"
    t.string "debitorkto"
    t.decimal "netto", precision: 15, scale: 2
    t.decimal "brutto", precision: 15, scale: 2
    t.string "mwstkz"
    t.string "geplliefjahrkw"
    t.date "geplliefdatum"
    t.boolean "gedruckt"
    t.string "zertifikat"
    t.boolean "selbstabholung"
    t.boolean "gutschrift"
    t.boolean "fruehbezug"
    t.date "ladedatum"
    t.date "versandavisdatum"
    t.string "strecke_auftragnr"
    t.string "strecke_eliefschnr"
    t.string "strecke_erechnnr"
    t.string "repl_id"
    t.string "repl_database"
    t.string "trfield"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["datum"], name: "index_wws_vliefer1_on_datum"
    t.index ["kundennr"], name: "index_wws_vliefer1_on_kundennr"
    t.index ["liefschnr"], name: "index_wws_vliefer1_on_liefschnr", unique: true
    t.index ["vauftragnr"], name: "index_wws_vliefer1_on_vauftragnr"
  end

  create_table "wws_vliefer2", id: false, force: :cascade do |t|
    t.string "liefschnr", null: false
    t.integer "posnr", null: false
    t.string "vauftragnr"
    t.integer "vauftragposnr"
    t.string "posart"
    t.string "einkaufverkauf"
    t.string "artikelnr"
    t.string "bezeichn1"
    t.string "bezeichn2"
    t.string "artikelart"
    t.decimal "liefmenge", precision: 15, scale: 6
    t.decimal "verpackmenge", precision: 15, scale: 6
    t.string "verpackschl"
    t.string "verpackeinh"
    t.integer "anzahlseriennr"
    t.text "eingabeseriennr"
    t.boolean "ausfaktur"
    t.boolean "fruehbezugerledigt"
    t.string "einheit"
    t.decimal "einhpreis", precision: 15, scale: 6
    t.decimal "netto", precision: 15, scale: 2
    t.decimal "brutto", precision: 15, scale: 2
    t.string "lager"
    t.string "chargennr"
    t.string "repl_id"
    t.string "repl_database"
    t.string "trfield"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "tour_id"
    t.integer "sequence_number"
    t.index ["liefschnr", "posnr"], name: "index_wws_vliefer2_on_liefschnr_and_posnr", unique: true
    t.index ["liefschnr"], name: "index_wws_vliefer2_on_liefschnr"
    t.index ["tour_id", "sequence_number"], name: "index_delivery_positions_on_tour_and_sequence", unique: true
    t.index ["tour_id", "sequence_number"], name: "index_wws_vliefer2_on_tour_id_and_sequence_number"
    t.index ["tour_id"], name: "index_wws_vliefer2_on_tour_id"
    t.index ["vauftragnr", "vauftragposnr"], name: "index_wws_vliefer2_on_vauftragnr_and_vauftragposnr"
  end

  create_table "wws_wiegeschein1", id: false, force: :cascade do |t|
    t.string "id", null: false
    t.string "dbid", null: false
    t.string "wiegescheinnr", null: false
    t.string "art"
    t.date "datum"
    t.string "uhrzeit"
    t.string "bediener"
    t.string "wiegungwaageid1"
    t.string "wiegungwaageid2"
    t.datetime "wiegungdatum1", precision: nil
    t.datetime "wiegungdatum2", precision: nil
    t.string "wiegungeinh"
    t.decimal "wiegungnetto1", precision: 15, scale: 6
    t.decimal "wiegungnetto2", precision: 15, scale: 6
    t.decimal "gewicht", precision: 15, scale: 6
    t.decimal "menge", precision: 15, scale: 6
    t.string "kundliefnr"
    t.string "artikelnr"
    t.string "kontraktnr"
    t.string "auftragnr"
    t.integer "posnr"
    t.string "lager"
    t.string "abteilung"
    t.string "lagerfach"
    t.string "chargennr"
    t.string "kfz_kennzeichen"
    t.string "spediteurnr"
    t.string "status"
    t.boolean "erledigt"
    t.boolean "zielschein"
    t.string "belegnr"
    t.string "erledigtbediener"
    t.date "erledigtdatum"
    t.string "erledigtuhrzeit"
    t.string "repl_id"
    t.string "repl_database"
    t.string "trfield"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["auftragnr"], name: "index_wws_wiegeschein1_on_auftragnr"
    t.index ["id", "dbid", "wiegescheinnr"], name: "idx_wiegeschein_pk", unique: true
  end

  add_foreign_key "wws_verkauf1", "wws_kunden1", column: "kundennr", primary_key: "kundennr", name: "wws_verkauf1_kundennr_fkey"
  add_foreign_key "wws_verkauf2", "wws_verkauf1", column: "vauftragnr", primary_key: "vauftragnr", name: "wws_verkauf2_vauftragnr_fkey"
  add_foreign_key "wws_vliefer1", "wws_kunden1", column: "kundennr", primary_key: "kundennr", name: "wws_vliefer1_kundennr_fkey"
  add_foreign_key "wws_vliefer2", "tours", validate: false
  add_foreign_key "wws_vliefer2", "wws_vliefer1", column: "liefschnr", primary_key: "liefschnr", name: "wws_vliefer2_liefschnr_fkey"
end
