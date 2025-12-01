# app/services/firebird/purchase_order_service.rb
module Firebird
  class PurchaseOrderService
    def initialize
      @connection = Connection.instance
    end

    def all
      sql = <<~SQL
        SELECT * FROM WWS_BESTELLUNG1
        ORDER BY BESTELLDAT DESC, BESTELLNR DESC
      SQL

      rows = @connection.query(sql)
      rows.map { |row| PurchaseOrder.new(row) }
    end

    def pending
      sql = <<~SQL
        SELECT * FROM WWS_BESTELLUNG1
        WHERE ERLEDIGT = 'N' OR ERLEDIGT IS NULL
        ORDER BY LIEFERTAG ASC, BESTELLNR ASC
      SQL

      rows = @connection.query(sql)
      rows.map { |row| PurchaseOrder.new(row) }
    end

    def find(id)
      sql = <<~SQL
        SELECT * FROM WWS_BESTELLUNG1
        WHERE BESTELLNR = #{id.to_i}
      SQL

      rows = @connection.query(sql)
      return nil if rows.empty?

      PurchaseOrder.new(rows.first)
    end

    def find_with_items(id)
      purchase_order = find(id)
      return nil unless purchase_order

      items = get_items(id)

      {
        purchase_order: purchase_order.as_json,
        items: items.map(&:as_json)
      }
    end

    def get_items(purchase_order_id)
      sql = <<~SQL
        SELECT * FROM WWS_BESTELLUNG2
        WHERE BESTELLNR = #{purchase_order_id.to_i}
        ORDER BY POSNR
      SQL

      rows = @connection.query(sql)
      rows.map { |row| PurchaseOrderItem.new(row) }
    end

    def update(id, attributes)
      return false if attributes.empty?

      set_clauses = []

      if attributes[:beststatus].present?
        set_clauses << "BESTSTATUS = '#{attributes[:beststatus]}'"
      end

      if attributes[:liefertag].present?
        set_clauses << "LIEFERTAG = '#{attributes[:liefertag]}'"
      end

      if attributes[:erledigt].present?
        set_clauses << "ERLEDIGT = '#{attributes[:erledigt]}'"
      end

      if attributes[:text1].present?
        set_clauses << "TEXT1 = '#{attributes[:text1]}'"
      end

      if attributes[:text2].present?
        set_clauses << "TEXT2 = '#{attributes[:text2]}'"
      end

      if attributes[:uhrzeit].present?
        set_clauses << "UHRZEIT = '#{attributes[:uhrzeit]}'"
      end

      return false if set_clauses.empty?

      sql = "UPDATE WWS_BESTELLUNG1 SET #{set_clauses.join(', ')} WHERE BESTELLNR = #{id.to_i}"
      @connection.execute(sql)
      true
    end

    def update_item(purchase_order_id, item_id, attributes)
      return false if attributes.empty?

      set_clauses = []

      if attributes[:menge].present?
        set_clauses << "MENGE = #{attributes[:menge].to_f}"
      end

      if attributes[:status].present?
        set_clauses << "STATUS = '#{attributes[:status]}'"
      end

      return false if set_clauses.empty?

      sql = <<~SQL
        UPDATE WWS_BESTELLUNG2#{' '}
        SET #{set_clauses.join(', ')}#{' '}
        WHERE BESTELLNR = #{purchase_order_id.to_i}#{' '}
        AND POSNR = #{item_id.to_i}
      SQL

      @connection.execute(sql)
      true
    end
  end

  # Model für Bestellungs-Kopfdaten
  class PurchaseOrder
    attr_reader :bestellnr, :bestelldat, :beststatus, :lieferantnr, :liefname,
                :liefadrnr, :ansprpartner, :lager, :kostenst, :kommission,
                :liefertag, :mwst, :erledigt, :text1, :text2, :uhrzeit,
                :auftragnr, :kbestellnr, :ladedatum, :ladetermin

    def initialize(row)
      @bestellnr = row["BESTELLNR"]
      @bestelldat = row["BESTELLDAT"]
      @beststatus = row["BESTSTATUS"]&.strip
      @lieferantnr = row["LIEFERANTNR"]
      @liefname = clean_encoding(row["LIEFNAME"])
      @liefadrnr = row["LIEFADRNR"]
      @ansprpartner = clean_encoding(row["ANSPRPARTNER"])
      @lager = row["LAGER"]
      @kostenst = row["KOSTENST"]
      @kommission = row["KOMMISSION"]
      @liefertag = row["LIEFERTAG"]
      @mwst = row["MWST"]
      @erledigt = row["ERLEDIGT"]&.strip
      @text1 = clean_encoding(row["TEXT1"])
      @text2 = clean_encoding(row["TEXT2"])
      @uhrzeit = row["UHRZEIT"]&.strip
      @auftragnr = row["AUFTRAGNR"]
      @kbestellnr = row["KBESTELLNR"]
      @ladedatum = row["LADEDATUM"]
      @ladetermin = row["LADETERMIN"]
    end

    def as_json
      {
        purchase_order_number: @bestellnr,
        order_date: @bestelldat,
        status: @beststatus,
        supplier_number: @lieferantnr,
        supplier_name: @liefname,
        supplier_address_number: @liefadrnr,
        contact_person: @ansprpartner,
        warehouse: @lager,
        cost_center: @kostenst,
        commission: @kommission,
        delivery_date: @liefertag,
        vat: @mwst,
        completed: @erledigt == "J",
        text_1: @text1,
        text_2: @text2,
        time: @uhrzeit,
        sales_order_number: @auftragnr,
        customer_order_number: @kbestellnr,
        loading_date: @ladedatum,
        loading_deadline: @ladetermin
      }
    end

    private

    def clean_encoding(value)
      return nil if value.nil?
      value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
    end
  end

  # Model für Bestellungs-Positionen
  class PurchaseOrderItem
    attr_reader :bestellnr, :posnr, :lager, :artikelnr, :liefartnr,
                :bezeichn1, :bezeichn2, :kontraktnr, :menge, :einheit,
                :gebindemg, :gebindeinh, :steuerschl, :einhpreis, :preiseinh,
                :betrag, :liefertag, :bishlief, :gewicht, :status

    def initialize(row)
      @bestellnr = row["BESTELLNR"]
      @posnr = row["POSNR"]
      @lager = row["LAGER"]
      @artikelnr = row["ARTIKELNR"]&.strip
      @liefartnr = row["LIEFARTNR"]&.strip
      @bezeichn1 = clean_encoding(row["BEZEICHN1"])
      @bezeichn2 = clean_encoding(row["BEZEICHN2"])
      @kontraktnr = row["KONTRAKTNR"]
      @menge = row["MENGE"]
      @einheit = row["EINHEIT"]&.strip
      @gebindemg = row["GEBINDEMG"]
      @gebindeinh = row["GEBINDEINH"]&.strip
      @steuerschl = row["STEUERSCHL"]
      @einhpreis = row["EINHPREIS"]
      @preiseinh = row["PREISEINH"]
      @betrag = row["BETRAG"]
      @liefertag = row["LIEFERTAG"]
      @bishlief = row["BISHLIEF"]
      @gewicht = row["GEWICHT"]
      @status = row["STATUS"]&.strip
    end

    def as_json
      {
        purchase_order_number: @bestellnr,
        position: @posnr,
        warehouse: @lager,
        article_number: @artikelnr,
        supplier_article_number: @liefartnr,
        description_1: @bezeichn1,
        description_2: @bezeichn2,
        contract_number: @kontraktnr,
        quantity: @menge,
        unit: @einheit,
        package_quantity: @gebindemg,
        package_unit: @gebindeinh,
        tax_code: @steuerschl,
        unit_price: @einhpreis,
        price_unit: @preiseinh,
        amount: @betrag,
        delivery_date: @liefertag,
        delivered_quantity: @bishlief,
        weight: @gewicht,
        status: @status
      }
    end

    private

    def clean_encoding(value)
      return nil if value.nil?
      value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
    end
  end
end
