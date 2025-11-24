# frozen_string_literal: true

class RecreateUnassignedDeliveryItems < ActiveRecord::Migration[8.0]
  def up
    drop_table :unassigned_delivery_items, if_exists: true

    create_table :unassigned_delivery_items do |t|
      # ============================================
      # Primärschlüssel aus Firebird
      # ============================================
      t.string :liefschnr, null: false, comment: "Lieferscheinnummer"
      t.integer :posnr, null: false, comment: "Positionsnummer"
      t.string :vauftragnr, comment: "Verkaufsauftragsnummer"

      # ============================================
      # Aus WWS_VERKAUF1 (Auftragskopf)
      # ============================================

      # Kundendaten
      t.string :kundennr, comment: "Kundennummer"
      t.string :kundname, comment: "Kundenname"

      # Adressen
      t.string :kundadrnr, comment: "Kundenadressnummer"
      t.string :liefadrnr, comment: "Lieferadressnummer"
      t.string :rechnadrnr, comment: "Rechnungsadressnummer"
      t.string :ladeort, comment: "Ladeort/Werksadresse"

      # Termine Auftrag
      t.date :datum, comment: "Auftragsdatum"
      t.date :geplliefdatum, comment: "Geplantes Lieferdatum"
      t.date :ladedatum, comment: "Ladedatum"
      t.date :ladetermin, comment: "Ladetermin"
      t.string :uhrzeit, comment: "Uhrzeit"

      # Fahrzeug/Transport
      t.string :lkwnr, comment: "LKW-Nummer"
      t.string :fahrzeug, comment: "Fahrzeugtyp"
      t.string :containernr, comment: "Containernummer"
      t.string :transportart, comment: "Transportart"
      t.string :spediteurnr, comment: "Spediteur-Nummer"
      t.string :kfzkennzeichen1, comment: "KFZ-Kennzeichen 1"
      t.string :kfzkennzeichen2, comment: "KFZ-Kennzeichen 2"
      t.string :lieferart, comment: "Lieferart"

      # Infotexte
      t.text :infoallgemein, comment: "Allgemeine Info"
      t.text :infoproduktion, comment: "Produktionsinfo"
      t.text :infoverladung, comment: "Verladungsinfo"
      t.text :infoliefsch, comment: "Lieferscheininfo"
      t.text :liefertext, comment: "Liefertext"

      # Projekt/Bestellung
      t.string :objekt, comment: "Projekt/Objekt/Baustelle"
      t.string :bestnrkd, comment: "Bestellnummer Kunde"
      t.string :besteller, comment: "Besteller"
      t.date :bestdatum, comment: "Bestelldatum"

      # Bearbeiter
      t.string :bediener, comment: "Bediener"
      t.string :vertreter, comment: "Vertreter"

      # ============================================
      # Aus WWS_VERKAUF2 (Positionen)
      # ============================================

      # Artikeldaten
      t.string :posart, comment: "Positionsart"
      t.string :artikelnr, comment: "Artikelnummer"
      t.string :artikelart, comment: "Artikelart"
      t.string :bezeichn1, comment: "Artikelbezeichnung 1"
      t.string :bezeichn2, comment: "Artikelbezeichnung 2"
      t.text :langtext, comment: "Langtext Artikel"
      t.text :langliefer, comment: "Liefertext Artikel"

      # Mengen
      t.decimal :menge, precision: 15, scale: 6, comment: "Menge"
      t.decimal :bishliefmg, precision: 15, scale: 6, comment: "Bisher gelieferte Menge"
      t.string :einheit, comment: "Einheit"
      t.string :einhschl, comment: "Einheitenschlüssel"
      t.string :preiseinh, comment: "Preiseinheit"

      # Gebinde
      t.decimal :gebindemg, precision: 15, scale: 6, comment: "Gebindemenge"
      t.string :gebindschl, comment: "Gebindeschlüssel"
      t.string :gebindeinh, comment: "Gebindeeinheit"
      t.decimal :gebinhalt, precision: 15, scale: 6, comment: "Gebindeinhalt"

      # Gewichte
      t.decimal :gewicht, precision: 15, scale: 6, comment: "Gewicht"
      t.decimal :ladungsgewicht, precision: 15, scale: 6, comment: "Ladungsgewicht"

      # Paletten
      t.integer :palanzahl, comment: "Palettenanzahl"
      t.string :palettennr, comment: "Palettennummer"

      # Preise Original
      t.decimal :listpreis, precision: 15, scale: 6, comment: "Listenpreis"
      t.decimal :einhpreis, precision: 15, scale: 6, comment: "Einzelpreis"
      t.decimal :netto, precision: 15, scale: 2, comment: "Nettobetrag"
      t.decimal :mwst, precision: 15, scale: 2, comment: "MwSt-Betrag"
      t.decimal :brutto, precision: 15, scale: 2, comment: "Bruttobetrag"
      t.decimal :rabatt, precision: 10, scale: 2, comment: "Rabatt %"
      t.string :rabattart, comment: "Rabattart"
      t.string :steuerschl, comment: "Steuerschlüssel"
      t.decimal :mwstsatz, precision: 10, scale: 2, comment: "MwSt-Satz"

      # Lager/Charge
      t.string :lager, comment: "Lager"
      t.string :lagerfach, comment: "Lagerfach"
      t.string :chargennr, comment: "Chargennummer"
      t.string :seriennr, comment: "Seriennummer"

      # ============================================
      # Planungsfelder (nur lokal)
      # ============================================
      t.integer :typ, default: 0, comment: "Typ"
      t.decimal :freight_price, precision: 15, scale: 2, default: 0.0, comment: "Frachtpreis"
      t.decimal :loading_price, precision: 15, scale: 2, default: 0.0, comment: "Ladepreis"
      t.decimal :unloading_price, precision: 15, scale: 2, default: 0.0, comment: "Entladepreis"
      t.string :vehicle_override, limit: 22, comment: "Fahrzeug-Override"
      t.integer :fahrzeugart_id, comment: "Fahrzeugart FK"
      t.string :kessel, limit: 50, comment: "Kessel"
      t.timestamp :beginn, comment: "Beginn"
      t.timestamp :ende, comment: "Ende"
      t.date :planned_date, comment: "Geplantes Datum"
      t.time :planned_time, comment: "Geplante Zeit"
      t.text :kund_kommentar, comment: "Kundenkommentar"
      t.text :werk_kommentar, comment: "Werkkommentar"
      t.text :planning_notes, comment: "Planungsnotizen"
      t.text :info, comment: "Info"
      t.integer :kund_pos, comment: "Kundenposition"
      t.integer :werk_pos, comment: "Werkposition"
      t.string :status, limit: 20, null: false, default: "draft", comment: "Status"
      t.integer :gedruckt, default: 0, comment: "Gedruckt"
      t.string :art, limit: 30, comment: "Art"
      t.integer :plan_nr, default: 0, comment: "Plannummer"
      t.string :kontrakt_nr, default: "0", comment: "Kontraktnummer"
      t.string :tabelle_herkunft, comment: "Herkunftstabelle"
      t.boolean :invoiced, null: false, default: false, comment: "Abgerechnet"
      t.integer :invoice_number, comment: "Rechnungsnummer"
      t.timestamp :invoiced_at, comment: "Abgerechnet am"

      # ============================================
      # Timestamps am Ende
      # ============================================
      t.timestamps
    end

    # Indizes
    add_index :unassigned_delivery_items, [ :liefschnr, :posnr ], unique: true, name: "idx_unassigned_items_position"
    add_index :unassigned_delivery_items, :vauftragnr
    add_index :unassigned_delivery_items, :kundennr
    add_index :unassigned_delivery_items, :kundadrnr
    add_index :unassigned_delivery_items, :ladeort
    add_index :unassigned_delivery_items, :ladedatum
    add_index :unassigned_delivery_items, :geplliefdatum
    add_index :unassigned_delivery_items, :planned_date
    add_index :unassigned_delivery_items, :status
    add_index :unassigned_delivery_items, :invoiced
    add_index :unassigned_delivery_items, :gedruckt
  end

  def down
    drop_table :unassigned_delivery_items
  end
end
