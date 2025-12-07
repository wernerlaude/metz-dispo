# app/pdfs/tour_pdf.rb
class TourPdf
  include Prawn::View

  FONT_PATH = Rails.root.join("app/assets/fonts")
  LOGO_PATH = Rails.root.join("app/assets/images/metz_logo.png")

  def initialize(tour, positions, deliveries_data: [], show_price: false)
    @tour = tour
    @positions = positions
    @deliveries_data = deliveries_data
    @show_price = show_price
    @document = Prawn::Document.new(
      page_size: "A4",
      margin: [ 30, 30, 50, 30 ]
    )
    setup_fonts
  end

  def render
    header
    tour_info_block
    positions_table
    page_footer

    document.render
  end

  private

  def setup_fonts
    font_families.update(
      "DejaVu" => {
        normal: "#{FONT_PATH}/DejaVuSans.ttf",
        bold: "#{FONT_PATH}/DejaVuSans-Bold.ttf",
        italic: "#{FONT_PATH}/DejaVuSans-Oblique.ttf",
        bold_italic: "#{FONT_PATH}/DejaVuSans-BoldOblique.ttf"
      }
    )
    font "DejaVu"
  end

  # ============================================
  # HEADER
  # ============================================

  def header
    # Versions-Hinweis ÜBER dem Titel
    version_text = @show_price ? "Büro-Exemplar" : "Fahrer-Exemplar"
    text version_text, size: 12, style: :bold
    move_down 5

    # Tourenplan Titel links
    text "Tourenplan Nr. #{safe_string(@tour.name)}", size: 18, style: :bold

    # Logo rechts oben
    if File.exist?(LOGO_PATH)
      image LOGO_PATH, at: [ bounds.width - 180, cursor + 55 ], width: 180
    end

    move_down 30
  end

  # ============================================
  # TOUR INFO BLOCK
  # ============================================

  def tour_info_block
    # Zwei-Spalten Layout
    left_column_width = bounds.width * 0.5
    right_column_width = bounds.width * 0.5

    # Linke Spalte
    bounding_box([ 0, cursor ], width: left_column_width) do
      info_row("LKW-Kennzeichen:", vehicle_license_plate)
      info_row("Hänger:", safe_string(@tour.trailer&.license_plate))
      info_row("Werk:", safe_string(@tour.loading_location&.werk_name))
    end

    # Rechte Spalte (gleiche Höhe)
    bounding_box([ left_column_width, cursor + 45 ], width: right_column_width) do
      info_row("Fahrer:", safe_string(@tour.driver&.full_name))
      info_row("Datum:", @tour.tour_date&.strftime("%d.%m.%Y"))
    end

    move_down 20
  end

  def info_row(label, value)
    text_box label, at: [ 0, cursor ], width: 100, size: 10
    text_box value || "-", at: [ 100, cursor ], width: 150, size: 10
    move_down 15
  end

  # ============================================
  # POSITIONS TABLE
  # ============================================

  def positions_table
    return if @positions.empty?

    table_data = build_table_data

    table(table_data, header: true, cell_style: { size: 9, padding: 5 }) do |t|
      # Header Styling
      t.row(0).font_style = :bold
      t.row(0).background_color = "F5F5F5"

      # Spaltenbreiten
      t.column(0).width = 45   # Kessel
      t.column(1).width = 180  # Kunde
      t.column(2).width = 80   # Menge
      t.column(3).width = 210  # Produkt

      # Rahmen für alle Zellen
      t.cells.borders = [ :top, :bottom, :left, :right ]
      t.cells.border_width = 0.5

      # Vertikale Ausrichtung
      t.cells.valign = :top
    end
  end

  def build_table_data
    data = [ [ "Kessel", "Kunde", "Menge", "Produkt" ] ]

    @positions.each do |position|
      delivery_data = find_delivery_data(position)

      # Hauptzeile mit allen 4 Spalten
      data << [
        kessel_cell(position),
        kunde_cell(position, delivery_data),
        menge_cell(position),
        produkt_cell(position)
      ]

      # Info-Zeile (colspan über Menge + Produkt)
      info_text = safe_string(position.infoallgemein) || safe_string(position.infoverladung) || ""
      data << [
        "",
        "",
        { content: "Info: #{info_text}", colspan: 2 }
      ]

      # Belade-Kommentar (colspan über Menge + Produkt)
      belade = safe_string(position.werk_kommentar) || ""
      data << [
        "",
        "",
        { content: "Belade-Kommentar: #{belade}", colspan: 2 }
      ]

      # Entlade-Kommentar (colspan über Menge + Produkt)
      entlade = safe_string(position.kund_kommentar) || ""
      data << [
        "",
        "",
        { content: "Entlade-Kommentar: #{entlade}", colspan: 2 }
      ]
    end

    data
  end

  def build_position_row(position, delivery_data)
    [
      kessel_cell(position),
      kunde_cell(position, delivery_data),
      menge_cell(position),
      produkt_cell(position)
    ]
  end

  # Kessel Spalte
  def kessel_cell(position)
    kessel_str = safe_string(position.kessel)
    return "-" if kessel_str.blank?

    # Formatiere "1,2,3" als mehrzeilig oder mit Leerzeichen
    kessel_values = kessel_str.split(",").map(&:strip).reject(&:blank?)
    return "-" if kessel_values.empty?

    # Bei mehreren Kesseln untereinander anzeigen
    kessel_values.join("\n")
  end

  # Kunde Spalte
  def kunde_cell(position, delivery_data)
    lines = []
    lines << "Liefern zu: (#{safe_string(position.liefschnr)})"

    if delivery_data && delivery_data[:delivery_address]
      addr = delivery_data[:delivery_address]
      lines << safe_string(addr[:name1]) if addr[:name1].present?
      lines << safe_string(addr[:name2]) if addr[:name2].present?
      lines << safe_string(addr[:strasse]) if addr[:strasse].present?
      lines << "#{safe_string(addr[:plz])} #{safe_string(addr[:ort])}" if addr[:plz].present? || addr[:ort].present?

      # Telefon
      telefon_parts = [ addr[:telefon1], addr[:telefon2] ].compact.reject(&:blank?)
      lines << "Telefon: #{telefon_parts.join(' / ')}" if telefon_parts.any?
    else
      lines << safe_string(position.kundname) || "Keine Adresse"
    end

    lines.join("\n")
  end

  # Menge Spalte
  def menge_cell(position)
    lines = []

    # Gewicht
    weight = calculate_weight(position)
    lines << "#{weight.to_i} kg" if weight > 0

    # Preis (nur wenn @show_price = true)
    if @show_price
      menge = position.menge.to_f
      netto = position.netto.to_f
      brutto = position.brutto.to_f

      lines << ""
      lines << "Netto: #{format_currency(netto)}" if netto > 0
      lines << "Brutto: #{format_currency(brutto)}" if brutto > 0
    end

    # Hänger
    lines << ""
    lines << "  [ ] Hänger"

    lines.join("\n")
  end

  # Produkt Spalte
  def produkt_cell(position)
    lines = []
    lines << safe_string(position.bezeichn1) if position.bezeichn1.present?
    lines << safe_string(position.bezeichn2) if position.bezeichn2.present?

    # Ladeort
    ladeort = safe_string(position.ladeort) || @tour.loading_location&.werk_name
    lines << ladeort if ladeort.present?

    lines.join("\n")
  end

  # ============================================
  # PAGE FOOTER
  # ============================================

  def page_footer
    repeat(:all) do
      bounding_box([ 0, 25 ], width: bounds.width, height: 20) do
        stroke_horizontal_rule

        move_down 5
        font_size(8) do
          text_box "Vertraulich", at: [ 0, cursor ], width: 100
          text_box "Seite #{page_number}/#{page_count}", at: [ bounds.width - 60, cursor ], width: 60, align: :right
        end
      end
    end
  end

  # ============================================
  # HELPER METHODS
  # ============================================

  def find_delivery_data(position)
    @deliveries_data.find { |d| d[:liefschnr] == position.liefschnr }
  end

  def calculate_weight(position)
    return position.gewicht.to_f if position.gewicht.to_f > 0
    return position.ladungsgewicht.to_f if position.ladungsgewicht.to_f > 0

    menge = position.menge.to_f
    einheit = position.einheit.to_s.upcase

    case einheit
    when "T", "TO"
      menge * 1000
    when "KG"
      menge
    when "SACK"
      menge * 25
    when "BB"
      menge * 600
    when "M³", "M3", "CBM"
      menge * 800
    else
      0
    end
  end

  def safe_string(value)
    return "" if value.nil?

    str = value.to_s

    if str.encoding == Encoding::ASCII_8BIT
      str.force_encoding("UTF-8")
    else
      str.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end
  rescue
    value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
  end

  def format_currency(value)
    return "" if value.nil? || value == 0
    sprintf("%.2f €", value).gsub(".", ",")
  end

  # Fahrzeug-Kennzeichen ermitteln (Tour oder aus Positionen)
  def vehicle_license_plate
    # Erst Tour-Fahrzeug prüfen
    if @tour.vehicle.present?
      return safe_string(@tour.vehicle.license_plate)
    end

    # Fallback: lkwnr aus erster Position holen
    first_position = @positions.find { |p| p.lkwnr.present? }
    if first_position&.lkwnr.present?
      # Versuche Fahrzeug anhand lkwnr zu finden
      vehicle = Vehicle.find_by(vehicle_number: first_position.lkwnr)
      return safe_string(vehicle&.license_plate) || "LKW #{first_position.lkwnr}"
    end

    "-"
  end
end