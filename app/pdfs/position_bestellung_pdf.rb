# app/pdfs/position_bestellung_pdf.rb
class PositionBestellungPdf
  include Prawn::View

  FONT_PATH = Rails.root.join("app/assets/fonts")
  LOGO_PATH = Rails.root.join("app/assets/images/metz_logo.png")

  def initialize(position, delivery_data: nil, loading_location_name: nil)
    @position = position
    @delivery_data = delivery_data
    @loading_location_name_override = loading_location_name
    @document = Prawn::Document.new(
      page_size: "A4",
      page_layout: :landscape,
      margin: [ 30, 40, 30, 40 ]
    )
    setup_fonts
  end

  def render
    header
    meta_info
    position_table
    footer

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
    # Linke Seite: DEUTSCHE TIERNAHRUNG
    bounding_box([ 0, cursor ], width: bounds.width / 2) do
      text "DEUTSCHE", size: 14, style: :bold
      text "TIERNAHRUNG", size: 10, color: "666666"
      move_down 5
      text "DEUTSCHE TIERNAHRUNG CREMER GMBH & CO. KG", size: 7, color: "999999"
    end

    # Rechte Seite: Metz Logo + Rechnungsempfänger
    if File.exist?(LOGO_PATH)
      image LOGO_PATH, at: [ bounds.width - 200, cursor + 10 ], width: 120
    end

    text_box "Rechnungsempfänger / Händler",
             at: [ bounds.width - 200, cursor - 30 ],
             width: 200,
             size: 8,
             style: :bold

    text_box "Hauptstraße 32 · 91723 Dittenheim\nTel: 09834 555 · Fax: 09834 1319",
             at: [ bounds.width - 200, cursor - 42 ],
             width: 200,
             size: 7,
             color: "666666"

    move_down 50
  end

  # ============================================
  # META INFO
  # ============================================

  def meta_info
    text "Bestellung lose Ware", size: 16, style: :bold
    move_down 15

    datum = @position.geplliefdatum&.strftime("%d.%m.%Y") ||
            @position.planned_date&.strftime("%d.%m.%Y") ||
            Date.current.strftime("%d.%m.%Y")
    uhrzeit = safe_string(@position.uhrzeit).presence || "03:00:00"

    text "Abholung am", size: 10
    move_down 3
    text "Datum: #{datum}    Uhrzeit: #{uhrzeit}", size: 11, style: :bold
    move_down 10

    text "Werk: #{loading_location_name}", size: 11, style: :bold
    move_down 20
  end

  # ============================================
  # POSITION TABLE
  # ============================================

  def position_table
    table_data = build_table_data

    table(table_data, header: true, cell_style: { size: 10, padding: [ 10, 8 ] }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "EEEEEE"
      t.row(0).height = 35

      # Spaltenbreiten (Querformat)
      t.column(0).width = 55   # Kessel
      t.column(1).width = 75   # Menge
      t.column(2).width = 190  # Artikelbezeichnung
      t.column(3).width = 200  # Warenempfänger
      t.column(4).width = 95   # Auftrags-Nr.
      t.column(5).width = 145  # Bemerkung

      t.cells.borders = [ :top, :bottom, :left, :right ]
      t.cells.border_width = 0.5
      t.cells.valign = :center  # <-- Korrigiert: :center statt :middle

      t.row(1).height = 60
    end
  end

  def build_table_data
    [
      [ "Kessel", "Menge", "Artikelbezeichnung", "Warenempfänger", "Auftrags-Nr.", "Bemerkung" ],
      [
        kessel_cell,
        menge_cell,
        artikel_cell,
        empfaenger_cell,
        auftrags_nr_cell,
        bemerkung_cell
      ]
    ]
  end

  def kessel_cell
    kessel_str = safe_string(@position.kessel)
    return "" if kessel_str.blank?

    kessel_str.split(",").map(&:strip).reject(&:blank?).join("\n")
  end

  def menge_cell
    menge = @position.menge.to_f
    einheit = safe_string(@position.einheit).presence || "kg"

    return "" if menge <= 0
    "#{menge.to_i} #{einheit}"
  end

  def artikel_cell
    lines = []
    lines << safe_string(@position.bezeichn1) if @position.bezeichn1.present?
    lines << safe_string(@position.bezeichn2) if @position.bezeichn2.present?
    lines.join("\n")
  end

  def empfaenger_cell
    lines = []

    if @delivery_data && @delivery_data[:delivery_address]
      addr = @delivery_data[:delivery_address]
      lines << safe_string(addr[:name1]) if addr[:name1].present?
      lines << safe_string(addr[:name2]) if addr[:name2].present?

      address_line = [
        safe_string(addr[:strasse]),
        "#{safe_string(addr[:plz])} #{safe_string(addr[:ort])}"
      ].reject(&:blank?).join(", ")
      lines << address_line if address_line.present?
    else
      lines << safe_string(@position.kundname) if @position.kundname.present?
    end

    lines.join("\n")
  end

  def auftrags_nr_cell
    safe_string(@position.vauftragnr).presence || safe_string(@position.liefschnr) || ""
  end

  def bemerkung_cell
    remarks = []
    remarks << safe_string(@position.infoallgemein) if @position.infoallgemein.present?
    remarks << safe_string(@position.infoverladung) if @position.infoverladung.present?
    remarks << safe_string(@position.werk_kommentar) if @position.werk_kommentar.present?
    remarks.join("\n")
  end

  # ============================================
  # FOOTER
  # ============================================

  def footer
    repeat(:all) do
      bounding_box([ 0, 20 ], width: bounds.width, height: 15) do
        font_size(7) do
          text_box "Gedruckt: #{Time.current.strftime('%d.%m.%Y %H:%M')}",
                   at: [ 0, cursor ], width: 150
        end
      end
    end
  end

  # ============================================
  # HELPER METHODS
  # ============================================

  def loading_location_name
    # Erst Override aus Parameter
    return safe_string(@loading_location_name_override) if @loading_location_name_override.present?

    # Dann aus Position
    return safe_string(@position.ladeort) if @position.ladeort.present?

    # Dann aus Tour
    if @position.tour&.loading_location.present?
      return safe_string(@position.tour.loading_location.werk_name)
    end

    "Metz Dittenheim"
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
end
