# app/pdfs/tour_pdf.rb
class TourPdf
  include Prawn::View

  FONT_PATH = Rails.root.join("app/assets/fonts")

  def initialize(tour, positions, deliveries_data: [])
    @tour = tour
    @positions = positions
    @deliveries_data = deliveries_data
    @document = Prawn::Document.new(
      page_size: "A4",
      margin: [ 40, 40, 40, 40 ]
    )
    setup_fonts
  end

  def render
    add_header
    add_tour_info
    add_positions_table
    add_footer

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

  # String-Encoding fixen für Firebird-Daten
  def safe_string(value)
    return "" if value.nil?

    str = value.to_s

    if str.encoding == Encoding::ASCII_8BIT
      # Daten sind bereits UTF-8, nur falsch markiert
      str.force_encoding("UTF-8")
    else
      str.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end
  rescue
    value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
  end

  def add_header
    text "Tourenplan", size: 20, style: :bold
    move_down 10
    stroke_horizontal_rule
    move_down 20
  end

  def add_tour_info
    tour_info = [
      [ "Tour:", safe_string(@tour.name) ],
      [ "Datum:", @tour.tour_date&.strftime("%d.%m.%Y") || "" ],
      [ "Fahrer:", safe_string(@tour.driver&.full_name) || "Nicht zugewiesen" ],
      [ "Fahrzeug:", safe_string(@tour.vehicle&.license_plate) || "Nicht zugewiesen" ],
      [ "Anhänger:", safe_string(@tour.trailer&.license_plate) || "Kein Anhänger" ]
    ]

    if @tour.loading_location.present?
      tour_info << [ "Ladeort:", safe_string(@tour.loading_location.werk_name) ]
    end

    table(tour_info, width: bounds.width / 2) do
      cells.borders = []
      cells.padding = 5
      column(0).font_style = :bold
    end

    move_down 30
  end

  def add_positions_table
    text "Lieferpositionen", size: 14, style: :bold
    move_down 10

    if @positions.empty?
      text "Keine Positionen zugewiesen", style: :italic
      return
    end

    table_data = [
      %w[# LS-Nr Pos Kunde/Adresse Ladeort Artikel Menge]
    ]

    @positions.each do |position|
      delivery_data = find_delivery_data(position)

      table_data << [
        position.sequence_number || "-",
        safe_string(position.liefschnr),
        position.posnr,
        format_address(delivery_data),
        safe_string(delivery_data&.dig(:ladeort)) || "-",
        format_article(position),
        format_quantity(position)
      ]
    end

    w = bounds.width

    table(table_data, header: true, column_widths: {
      0 => w * 0.04,
      1 => w * 0.10,
      2 => w * 0.05,
      3 => w * 0.30,
      4 => w * 0.15,
      5 => w * 0.22,
      6 => w * 0.14
    }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "EEEEEE"
      t.cells.borders = [ :top, :bottom ]
      t.cells.border_width = 0.5
      t.cells.padding = 5
      t.cells.size = 9
    end
  end

  def add_footer
    move_down 30
    text "Gesamt: #{@positions.count} Position(en)", style: :italic

    move_down 20
    stroke_horizontal_rule
    move_down 10

    text "Unterschrift Fahrer: _________________________", size: 10
  end

  def find_delivery_data(position)
    @deliveries_data.find { |d| d[:liefschnr] == position.liefschnr }
  end

  def format_address(delivery_data)
    return "Keine Adresse" unless delivery_data

    addr = delivery_data[:delivery_address]
    return safe_string(delivery_data[:customer_name]) || "Keine Adresse" unless addr

    [
      safe_string(addr[:name1]),
      safe_string(addr[:name2]).presence,
      safe_string(addr[:strasse]),
      "#{safe_string(addr[:plz])} #{safe_string(addr[:ort])}"
    ].compact.join("\n")
  end

  def format_article(position)
    [
      safe_string(position.bezeichn1),
      safe_string(position.bezeichn2)
    ].compact.map(&:presence).compact.join("\n")
  end

  def format_quantity(position)
    menge = position.liefmenge || position.menge
    "#{menge} #{safe_string(position.einheit)}"
  end
end
