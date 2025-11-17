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

ActiveRecord::Schema[8.1].define(version: 2025_11_17_150911) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "Spedion_Auftrag", id: :serial, force: :cascade do |t|
    t.string "Art", limit: 30
    t.integer "AuftrNr"
    t.datetime "Beginn", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "Brutto", limit: 15
    t.string "Einheit", limit: 20
    t.datetime "Ende", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "Gebinhalt"
    t.integer "Gedruckt", default: 0, null: false
    t.text "Info"
    t.string "Kessel", limit: 50
    t.string "KontraktNr", limit: 255, default: "0", null: false
    t.integer "KundAdrNr"
    t.string "LiefschNr", limit: 255
    t.integer "Menge"
    t.integer "PlanNr", default: 0, null: false
    t.integer "PosNr"
    t.string "Preis", limit: 15
    t.integer "ProdNr"
    t.string "Tabelle_Herkunft", limit: 255, null: false
    t.integer "Typ", null: false
    t.integer "WerkAdrNr"
    t.integer "idFahrzeugart"
    t.integer "idTour"
    t.string "kundKommentar", limit: 45
    t.integer "kundPos"
    t.string "werkKommentar", limit: 45
    t.integer "werkPos"
  end

  create_table "Spedion_Fahrer", id: :serial, force: :cascade do |t|
    t.integer "Aktiv", default: 1, null: false
    t.integer "Art", default: 0, null: false
    t.string "Nachname", limit: 45, null: false
    t.string "Pin", limit: 45, null: false
    t.string "Vorname", limit: 45, null: false
    t.integer "idFahrzeug", default: 0, null: false
    t.integer "idHaenger", default: 0, null: false
    t.integer "idTablet", default: 0, null: false
  end

  create_table "Spedion_Fahrzeug", id: false, force: :cascade do |t|
    t.integer "Art"
    t.string "Fahrzeugnr", limit: 45
    t.string "Kennzeichen", limit: 45
    t.integer "id"
  end

  create_table "Spedion_Haenger", id: false, force: :cascade do |t|
    t.integer "art"
    t.integer "id"
    t.string "kennzeichen", limit: 45
  end

  create_table "Spedion_Lademittel", id: false, force: :cascade do |t|
    t.integer "Auftrnr"
    t.integer "Container_minus"
    t.integer "Container_plus"
    t.integer "Datum"
    t.integer "Kundennr"
    t.integer "Palette_minus"
    t.integer "Palette_plus"
    t.integer "id"
  end

  create_table "Spedion_Tour", id: :serial, force: :cascade do |t|
    t.datetime "Abfahrt", precision: nil
    t.datetime "Ankunft", precision: nil
    t.date "Datum", null: false
    t.float "Diesel_Ende"
    t.float "Diesel_Start"
    t.boolean "Erledigt", default: false, null: false
    t.datetime "Erstellt", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.float "Kilometer_Ende", limit: 24
    t.float "Kilometer_Start", limit: 24
    t.string "Lieferart", limit: 10, default: ""
    t.string "Spedition", limit: 255, null: false
    t.integer "Typ", limit: 2, null: false
    t.time "Uhrzeit", null: false
    t.boolean "gesendet", default: false, null: false
    t.integer "idFahrer", null: false
    t.integer "idFahrzeug", null: false
    t.integer "idHaenger"
  end

  create_table "Sperrliste_Fahrer", id: false, force: :cascade do |t|
    t.integer "AdrNr"
    t.integer "id"
    t.integer "idFahrer"
  end

  create_table "adressen", primary_key: "nummer", id: :string, force: :cascade do |t|
    t.string "anrede"
    t.string "art"
    t.string "branche"
    t.string "briefanr"
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.string "frei1"
    t.string "frei2"
    t.string "frei3"
    t.string "frei4"
    t.string "homepage"
    t.string "knr"
    t.string "land"
    t.string "lbranche"
    t.string "lname1"
    t.string "lname2"
    t.string "name1"
    t.string "name2"
    t.string "nat"
    t.string "ort"
    t.string "plz"
    t.string "postfach"
    t.string "postfort"
    t.string "postfplz"
    t.string "repl_database"
    t.string "repl_id"
    t.string "strasse"
    t.string "telefax"
    t.string "telefon1"
    t.string "telefon2"
    t.string "trfield"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["knr"], name: "index_adressen_on_knr"
    t.index ["nummer"], name: "index_adressen_on_nummer", unique: true
  end

  create_table "drivers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "driver_type", default: 0, null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "pin", null: false
    t.integer "tablet_id", default: 0
    t.integer "trailer_id", default: 0
    t.datetime "updated_at", null: false
    t.integer "vehicle_id", default: 0
    t.index ["active"], name: "index_drivers_on_active"
    t.index ["driver_type"], name: "index_drivers_on_driver_type"
    t.index ["pin"], name: "index_drivers_on_pin", unique: true
  end

  create_table "drivers_clone", id: false, force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at"
    t.integer "driver_type"
    t.string "first_name"
    t.bigint "id"
    t.string "last_name"
    t.string "pin"
    t.integer "tablet_id"
    t.integer "trailer_id"
    t.datetime "updated_at"
    t.integer "vehicle_id"
  end

  create_table "drivers_clone1", id: false, force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at"
    t.integer "driver_type"
    t.string "first_name"
    t.bigint "id"
    t.string "last_name"
    t.string "pin"
    t.integer "tablet_id"
    t.integer "trailer_id"
    t.datetime "updated_at"
    t.integer "vehicle_id"
  end

  create_table "loading_locations", force: :cascade do |t|
    t.boolean "active", default: true
    t.text "address"
    t.string "contact_person"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_loading_locations_on_active"
    t.index ["name"], name: "index_loading_locations_on_name"
  end

  create_table "loading_locations_clone", id: false, force: :cascade do |t|
    t.boolean "active"
    t.text "address"
    t.string "contact_person"
    t.datetime "created_at", precision: nil
    t.bigint "id"
    t.string "name"
    t.string "phone"
    t.datetime "updated_at", precision: nil
  end

  create_table "orders", force: :cascade do |t|
    t.string "art", limit: 30
    t.integer "auftr_nr"
    t.datetime "beginn", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "brutto", limit: 15
    t.string "einheit", limit: 20
    t.datetime "ende", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "gebinhalt"
    t.integer "gedruckt", default: 0, null: false
    t.integer "id_fahrzeugart"
    t.integer "id_tour"
    t.text "info"
    t.string "kessel", limit: 50
    t.string "kontrakt_nr", default: "0", null: false
    t.integer "kund_adr_nr"
    t.string "kund_kommentar", limit: 45
    t.integer "kund_pos"
    t.string "liefsch_nr"
    t.integer "menge"
    t.integer "plan_nr", default: 0, null: false
    t.integer "pos_nr"
    t.string "preis", limit: 15
    t.integer "prod_nr"
    t.string "tabelle_herkunft", null: false
    t.integer "typ", limit: 2, null: false, comment: "Sackware=0 Lose Ware=1"
    t.integer "werk_adr_nr"
    t.string "werk_kommentar", limit: 45
    t.integer "werk_pos"
    t.index ["id_tour"], name: "fk_spedion_place_spedion_tour1_idx"
  end

  create_table "sperrliste_fahrer", id: false, force: :cascade do |t|
    t.integer "adrnr", null: false
    t.integer "id", null: false
    t.integer "idfahrer", null: false
  end

  create_table "tours", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "driver_id"
    t.bigint "loading_location_id"
    t.string "name", null: false
    t.text "notes"
    t.integer "total_positions", default: 0
    t.decimal "total_weight", precision: 10, scale: 2, default: "0.0"
    t.date "tour_date", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle"
    t.index ["driver_id"], name: "index_tours_on_driver_id"
    t.index ["loading_location_id"], name: "index_tours_on_loading_location_id"
    t.index ["name", "tour_date"], name: "index_tours_on_name_and_tour_date", unique: true
    t.index ["tour_date", "vehicle"], name: "index_tours_on_tour_date_and_vehicle"
    t.index ["tour_date"], name: "index_tours_on_tour_date"
    t.index ["vehicle"], name: "index_tours_on_vehicle"
  end

  create_table "unassigned_delivery_items", force: :cascade do |t|
    t.string "art", limit: 30
    t.string "artikel_nr", limit: 50
    t.datetime "beginn", precision: nil
    t.string "bezeichnung", limit: 255
    t.decimal "brutto", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.string "einheit", limit: 20
    t.datetime "ende", precision: nil
    t.integer "fahrzeugart_id"
    t.decimal "freight_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "gebinhalt", precision: 15, scale: 2
    t.integer "gedruckt", default: 0
    t.text "info"
    t.integer "invoice_number"
    t.boolean "invoiced", default: false, null: false
    t.datetime "invoiced_at", precision: nil
    t.string "kessel", limit: 50
    t.string "kontrakt_nr", default: "0"
    t.integer "kund_adr_nr"
    t.text "kund_kommentar"
    t.integer "kund_pos"
    t.string "liefschnr", null: false
    t.text "loading_address_override"
    t.decimal "loading_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "menge", precision: 15, scale: 2
    t.integer "plan_nr", default: 0
    t.date "planned_date"
    t.time "planned_time"
    t.text "planning_notes"
    t.integer "posnr", null: false
    t.string "status", limit: 20, default: "draft", null: false
    t.string "tabelle_herkunft"
    t.integer "typ", default: 0
    t.text "unloading_address_override"
    t.decimal "unloading_price", precision: 15, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.integer "vauftragnr"
    t.string "vehicle_override", limit: 22
    t.integer "werk_adr_nr"
    t.text "werk_kommentar"
    t.integer "werk_pos"
    t.index ["gedruckt"], name: "index_unassigned_delivery_items_on_gedruckt"
    t.index ["invoiced"], name: "index_unassigned_delivery_items_on_invoiced"
    t.index ["kund_adr_nr"], name: "index_unassigned_delivery_items_on_kund_adr_nr"
    t.index ["liefschnr", "posnr"], name: "idx_unassigned_items_position", unique: true
    t.index ["planned_date"], name: "index_unassigned_delivery_items_on_planned_date"
    t.index ["status"], name: "index_unassigned_delivery_items_on_status"
    t.index ["vauftragnr"], name: "index_unassigned_delivery_items_on_vauftragnr"
  end

  create_table "unassigned_delivery_items_clone", id: false, force: :cascade do |t|
    t.string "art", limit: 30
    t.string "artikel_nr", limit: 50
    t.datetime "beginn"
    t.string "bezeichnung", limit: 255
    t.decimal "brutto", precision: 15, scale: 2
    t.datetime "created_at"
    t.string "customer_name"
    t.string "delivery_address_city"
    t.text "delivery_address_full"
    t.string "delivery_address_name"
    t.string "delivery_address_street"
    t.string "delivery_address_zip"
    t.string "einheit", limit: 20
    t.datetime "ende"
    t.integer "fahrzeugart_id"
    t.decimal "freight_price", precision: 15, scale: 2
    t.decimal "gebinhalt", precision: 15, scale: 2
    t.integer "gedruckt"
    t.bigint "id"
    t.text "info"
    t.integer "invoice_number"
    t.boolean "invoiced"
    t.datetime "invoiced_at"
    t.string "kessel", limit: 50
    t.string "kontrakt_nr", limit: 255
    t.integer "kund_adr_nr"
    t.text "kund_kommentar"
    t.integer "kund_pos"
    t.string "liefschnr"
    t.text "loading_address_override"
    t.decimal "loading_price", precision: 15, scale: 2
    t.decimal "menge", precision: 15, scale: 2
    t.integer "plan_nr"
    t.date "planned_date"
    t.time "planned_time"
    t.text "planning_notes"
    t.integer "posnr"
    t.integer "sequence_number"
    t.string "status", limit: 20
    t.string "tabelle_herkunft", limit: 255
    t.integer "tour_id"
    t.integer "typ"
    t.text "unloading_address_override"
    t.decimal "unloading_price", precision: 15, scale: 2
    t.datetime "updated_at"
    t.integer "vauftragnr"
    t.string "vehicle_override", limit: 22
    t.integer "werk_adr_nr"
    t.text "werk_kommentar"
    t.integer "werk_pos"
  end

  create_table "vehicles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "license_plate", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle_number"
    t.integer "vehicle_type", default: 0, null: false
    t.index ["license_plate"], name: "index_vehicles_on_license_plate", unique: true
    t.index ["vehicle_number"], name: "index_vehicles_on_vehicle_number"
    t.index ["vehicle_type"], name: "index_vehicles_on_vehicle_type"
  end

  create_table "wws_kunden1", primary_key: "kundennr", id: :string, force: :cascade do |t|
    t.boolean "bonusberecht"
    t.string "bundesland"
    t.datetime "created_at", precision: nil, null: false
    t.date "datumaustritt"
    t.date "datumeintritt"
    t.date "datumlauszug"
    t.string "edi_iln"
    t.string "edi_kundennr"
    t.string "edi_prefix"
    t.string "edi_typ"
    t.string "edi_uebertrnr"
    t.boolean "gekuendigt"
    t.string "geschkonto"
    t.boolean "kontoauszug"
    t.string "kuendgrund"
    t.string "kundgruppe"
    t.integer "lfdrechnnr"
    t.string "mitgliednr"
    t.integer "nrlauszug"
    t.boolean "offeneposten"
    t.integer "pflichtanteile"
    t.integer "pflichtanteilegez"
    t.decimal "rabatt", precision: 10, scale: 2
    t.string "rechnformular"
    t.string "rechnkunde"
    t.string "repl_database"
    t.string "repl_id"
    t.decimal "saldolauszug", precision: 15, scale: 2
    t.decimal "saldorechnung", precision: 15, scale: 2
    t.decimal "selbstabhbetrag", precision: 15, scale: 2
    t.decimal "selbstabhrabatt", precision: 10, scale: 2
    t.string "trfield"
    t.string "umsatzsteuer"
    t.datetime "updated_at", precision: nil, null: false
    t.text "werbetext"
    t.string "zahlungart"
    t.boolean "zinsbuchung"
    t.decimal "zinssatzhaben", precision: 10, scale: 2
    t.decimal "zinssatzsoll", precision: 10, scale: 2
    t.string "zinstabhaben"
    t.string "zinstabsoll"
    t.index ["kundennr"], name: "index_wws_kunden1_on_kundennr", unique: true
    t.index ["kundgruppe"], name: "index_wws_kunden1_on_kundgruppe"
  end

  create_table "wws_verkauf1", primary_key: "vauftragnr", id: :string, force: :cascade do |t|
    t.date "angebdatum"
    t.string "angebotnr"
    t.boolean "auftrbestgedruckt"
    t.string "auftstatus"
    t.string "bediener"
    t.string "best_anrede"
    t.string "best_briefanrede"
    t.date "bestdatum"
    t.string "besteller"
    t.string "bestnrkd"
    t.boolean "betrauftrgedruckt"
    t.boolean "bruttoberechn"
    t.string "containernr"
    t.datetime "created_at", precision: nil, null: false
    t.date "datum"
    t.string "debitorkto"
    t.boolean "erledigt"
    t.string "fahrzeug"
    t.boolean "fremdwaehrung"
    t.datetime "geaendertam", precision: nil
    t.string "gebiet"
    t.date "geplliefdatum"
    t.string "geplliefjahrkw"
    t.text "infoallgemein"
    t.text "infoauftrbest"
    t.text "infoliefsch"
    t.text "infoproduktion"
    t.text "infoverladung"
    t.string "kdabteilung"
    t.string "kfzkennzeichen1"
    t.string "kfzkennzeichen2"
    t.string "kostenst"
    t.string "kundadrnr"
    t.string "kundennr"
    t.string "kundname"
    t.string "kundwaehrcode"
    t.date "ladedatum"
    t.string "ladeort"
    t.date "ladetermin"
    t.string "lager"
    t.boolean "lastschrift"
    t.string "liefadrnr"
    t.string "lieferart"
    t.text "liefertext"
    t.string "lkwnr"
    t.string "mwstkz"
    t.integer "nettotg"
    t.string "objekt"
    t.date "prodtermin"
    t.string "rechnadrnr"
    t.string "repl_database"
    t.string "repl_id"
    t.decimal "selbstabhrabatt", precision: 10, scale: 2
    t.decimal "skonto1pr", precision: 10, scale: 2
    t.integer "skonto1tg"
    t.decimal "skonto2pr", precision: 10, scale: 2
    t.integer "skonto2tg"
    t.string "spediteurnr"
    t.string "transportart"
    t.string "trfield"
    t.string "uhrzeit"
    t.decimal "umrfaktor", precision: 10, scale: 6
    t.datetime "updated_at", precision: nil, null: false
    t.integer "valuta"
    t.string "versandart"
    t.string "vertragstyp"
    t.string "vertreter"
    t.string "verzgrund"
    t.string "waehrcode"
    t.text "zahlbedtext"
    t.index ["datum"], name: "index_wws_verkauf1_on_datum"
    t.index ["kundennr"], name: "index_wws_verkauf1_on_kundennr"
    t.index ["vauftragnr"], name: "index_wws_verkauf1_on_vauftragnr", unique: true
  end

  create_table "wws_verkauf2", id: false, force: :cascade do |t|
    t.string "abteilung"
    t.string "artikelart"
    t.string "artikelnr"
    t.string "bezeichn1"
    t.string "bezeichn2"
    t.decimal "bishliefmg", precision: 15, scale: 6
    t.decimal "brutto", precision: 15, scale: 2
    t.decimal "brutto2", precision: 15, scale: 2
    t.decimal "bruttpreis", precision: 15, scale: 6
    t.decimal "bruttpreis2", precision: 15, scale: 6
    t.string "chargennr"
    t.datetime "created_at", precision: nil, null: false
    t.string "einheit"
    t.decimal "einhpreis", precision: 15, scale: 6
    t.decimal "einhpreis2", precision: 15, scale: 6
    t.string "einhschl"
    t.string "gebindeinh"
    t.decimal "gebindemg", precision: 15, scale: 6
    t.string "gebindschl"
    t.decimal "gebinhalt", precision: 15, scale: 6
    t.decimal "gewicht", precision: 15, scale: 6
    t.decimal "ladungsgewicht", precision: 15, scale: 6
    t.string "lager"
    t.string "lagerfach"
    t.text "langliefer"
    t.text "langrechn"
    t.text "langtext"
    t.text "langzusaet"
    t.decimal "listbrutto", precision: 15, scale: 6
    t.decimal "listbrutto2", precision: 15, scale: 6
    t.decimal "listpreis", precision: 15, scale: 6
    t.decimal "listpreis2", precision: 15, scale: 6
    t.decimal "menge", precision: 15, scale: 6
    t.decimal "mwst", precision: 15, scale: 2
    t.decimal "mwst2", precision: 15, scale: 2
    t.decimal "mwstsatz", precision: 10, scale: 2
    t.decimal "netto", precision: 15, scale: 2
    t.decimal "netto2", precision: 15, scale: 2
    t.integer "palanzahl"
    t.string "palettennr"
    t.string "posart"
    t.integer "posnr", null: false
    t.string "preiseinh"
    t.boolean "prod_erledigt"
    t.string "prodanlage"
    t.string "produktionsauftragid"
    t.decimal "rabatt", precision: 10, scale: 2
    t.decimal "rabatt2", precision: 10, scale: 2
    t.string "rabattart"
    t.string "rabattart2"
    t.string "repl_database"
    t.string "repl_id"
    t.string "rezepturnr"
    t.string "rezepturnr2"
    t.string "ruestliste"
    t.string "seriennr"
    t.string "steuerschl"
    t.string "trfield"
    t.string "umsatzgrp"
    t.datetime "updated_at", precision: nil, null: false
    t.string "vauftragnr", null: false
    t.string "vorprodanlage"
    t.string "zuabschlagnr"
    t.string "zuabschlagnr2"
    t.index ["artikelnr"], name: "index_wws_verkauf2_on_artikelnr"
    t.index ["vauftragnr", "posnr"], name: "index_wws_verkauf2_on_vauftragnr_and_posnr", unique: true
    t.index ["vauftragnr"], name: "index_wws_verkauf2_on_vauftragnr"
  end

  create_table "wws_vliefer1", primary_key: "liefschnr", id: :string, force: :cascade do |t|
    t.string "arechnungnr"
    t.string "bediener"
    t.decimal "brutto", precision: 15, scale: 2
    t.datetime "created_at", precision: nil, null: false
    t.date "datum"
    t.string "debitorkto"
    t.string "einkaufverkauf"
    t.boolean "fruehbezug"
    t.boolean "gedruckt"
    t.date "geplliefdatum"
    t.string "geplliefjahrkw"
    t.boolean "gutschrift"
    t.string "kostenst"
    t.string "kundadrnr"
    t.string "kundennr"
    t.string "kundname"
    t.date "ladedatum"
    t.string "liefadrnr"
    t.string "mwstkz"
    t.decimal "netto", precision: 15, scale: 2
    t.string "rechnadrnr"
    t.string "rechnungnr"
    t.string "repl_database"
    t.string "repl_id"
    t.boolean "selbstabholung"
    t.string "strecke_auftragnr"
    t.string "strecke_eliefschnr"
    t.string "strecke_erechnnr"
    t.string "trfield"
    t.datetime "updated_at", precision: nil, null: false
    t.string "vauftragnr"
    t.date "versandavisdatum"
    t.string "vertreter"
    t.string "zertifikat"
    t.index ["datum"], name: "index_wws_vliefer1_on_datum"
    t.index ["kundennr"], name: "index_wws_vliefer1_on_kundennr"
    t.index ["liefschnr"], name: "index_wws_vliefer1_on_liefschnr", unique: true
    t.index ["vauftragnr"], name: "index_wws_vliefer1_on_vauftragnr"
  end

  create_table "wws_vliefer2", id: false, force: :cascade do |t|
    t.integer "anzahlseriennr"
    t.string "artikelart"
    t.string "artikelnr"
    t.boolean "ausfaktur"
    t.string "bezeichn1"
    t.string "bezeichn2"
    t.decimal "brutto", precision: 15, scale: 2
    t.string "chargennr"
    t.datetime "created_at", precision: nil, null: false
    t.text "eingabeseriennr"
    t.string "einheit"
    t.decimal "einhpreis", precision: 15, scale: 6
    t.string "einkaufverkauf"
    t.boolean "fruehbezugerledigt"
    t.string "lager"
    t.decimal "liefmenge", precision: 15, scale: 6
    t.string "liefschnr", null: false
    t.decimal "netto", precision: 15, scale: 2
    t.string "posart"
    t.integer "posnr", null: false
    t.string "repl_database"
    t.string "repl_id"
    t.integer "sequence_number"
    t.bigint "tour_id"
    t.string "trfield"
    t.datetime "updated_at", precision: nil, null: false
    t.string "vauftragnr"
    t.integer "vauftragposnr"
    t.string "verpackeinh"
    t.decimal "verpackmenge", precision: 15, scale: 6
    t.string "verpackschl"
    t.index ["liefschnr", "posnr"], name: "index_wws_vliefer2_on_liefschnr_and_posnr", unique: true
    t.index ["liefschnr"], name: "index_wws_vliefer2_on_liefschnr"
    t.index ["tour_id", "sequence_number"], name: "index_delivery_positions_on_tour_and_sequence", unique: true
    t.index ["tour_id", "sequence_number"], name: "index_wws_vliefer2_on_tour_id_and_sequence_number"
    t.index ["tour_id"], name: "index_wws_vliefer2_on_tour_id"
    t.index ["vauftragnr", "vauftragposnr"], name: "index_wws_vliefer2_on_vauftragnr_and_vauftragposnr"
  end

  create_table "wws_wiegeschein1", id: false, force: :cascade do |t|
    t.string "abteilung"
    t.string "art"
    t.string "artikelnr"
    t.string "auftragnr"
    t.string "bediener"
    t.string "belegnr"
    t.string "chargennr"
    t.datetime "created_at", precision: nil, null: false
    t.date "datum"
    t.string "dbid", null: false
    t.boolean "erledigt"
    t.string "erledigtbediener"
    t.date "erledigtdatum"
    t.string "erledigtuhrzeit"
    t.decimal "gewicht", precision: 15, scale: 6
    t.string "id", null: false
    t.string "kfz_kennzeichen"
    t.string "kontraktnr"
    t.string "kundliefnr"
    t.string "lager"
    t.string "lagerfach"
    t.decimal "menge", precision: 15, scale: 6
    t.integer "posnr"
    t.string "repl_database"
    t.string "repl_id"
    t.string "spediteurnr"
    t.string "status"
    t.string "trfield"
    t.string "uhrzeit"
    t.datetime "updated_at", precision: nil, null: false
    t.string "wiegescheinnr", null: false
    t.datetime "wiegungdatum1", precision: nil
    t.datetime "wiegungdatum2", precision: nil
    t.string "wiegungeinh"
    t.decimal "wiegungnetto1", precision: 15, scale: 6
    t.decimal "wiegungnetto2", precision: 15, scale: 6
    t.string "wiegungwaageid1"
    t.string "wiegungwaageid2"
    t.boolean "zielschein"
    t.index ["auftragnr"], name: "index_wws_wiegeschein1_on_auftragnr"
    t.index ["id", "dbid", "wiegescheinnr"], name: "idx_wiegeschein_pk", unique: true
  end

  add_foreign_key "wws_verkauf1", "wws_kunden1", column: "kundennr", primary_key: "kundennr", name: "wws_verkauf1_kundennr_fkey"
  add_foreign_key "wws_verkauf2", "wws_verkauf1", column: "vauftragnr", primary_key: "vauftragnr", name: "wws_verkauf2_vauftragnr_fkey"
  add_foreign_key "wws_vliefer1", "wws_kunden1", column: "kundennr", primary_key: "kundennr", name: "wws_vliefer1_kundennr_fkey"
  add_foreign_key "wws_vliefer2", "tours", validate: false
  add_foreign_key "wws_vliefer2", "wws_vliefer1", column: "liefschnr", primary_key: "liefschnr", name: "wws_vliefer2_liefschnr_fkey"
end
