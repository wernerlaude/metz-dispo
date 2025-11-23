# app/pdfs/tour_pdf.rb
class TourPdf
  include Prawn::View

  def initialize(tour, positions)
    @tour = tour
    @positions = positions
    @document = Prawn::Document.new(
      page_size: 'A4',
      margin: [40, 40, 40, 40]
    )
  end

  def render
    add_header
    add_tour_info
    add_positions_table
    add_footer

    document.render
  end

  private

  def add_header
    text "Tourenplan", size: 20, style: :bold
    move_down 10
    stroke_horizontal_rule
    move_down 20
  end

  def add_tour_info
    tour_info = [
      ["Tour:", @tour.name],
      ["Datum:", @tour.tour_date&.strftime("%d.%m.%Y")],
      ["Fahrer:", @tour.driver&.full_name || "Nicht zugewiesen"],
      ["Fahrzeug:", @tour.vehicle&.license_plate || "Nicht zugewiesen"],
      ["Anhänger:", @tour.trailer&.license_plate || "Kein Anhänger"]
    ]

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
      ["#", "LS-Nr", "Pos", "Kunde/Adresse", "Artikel", "Menge"]
    ]

    @positions.each do |position|
      delivery = position.delivery
      address = delivery&.delivery_address

      table_data << [
        position.sequence_number || "-",
        position.liefschnr,
        position.posnr,
        format_address(address, delivery),
        format_article(position),
        format_quantity(position)
      ]
    end

    table(table_data, width: bounds.width, header: true) do
      row(0).font_style = :bold
      row(0).background_color = 'EEEEEE'
      cells.borders = [:top, :bottom]
      cells.border_width = 0.5
      cells.padding = 8
      column(0).width = 30
      column(1).width = 60
      column(2).width = 40
      column(4).width = 120
      column(5).width = 80
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

  def format_address(address, delivery)
    if address
      "#{address.name1}\n#{address.strasse}\n#{address.plz} #{address.ort}"
    elsif delivery
      "#{delivery.kundname}\n(Adresse nicht gefunden)"
    else
      "Keine Adresse"
    end
  end

  def format_article(position)
    "#{position.bezeichn1}\n#{position.bezeichn2}".strip
  end

  def format_quantity(position)
    "#{position.liefmenge} #{position.einheit}"
  end
end