# app/services/address_cache_service.rb
#
# Zentraler Service für Adress-Lookups mit Caching und Geocoding.
# Wird von Controllers und Models verwendet.
#
# Verwendung:
#   AddressCacheService.find(12345)
#   # => { name1: "Müller GmbH", strasse: "Hauptstr. 1", plz: "90000", ort: "Nürnberg", lat: 49.45, lng: 11.08, ... }
#
#   AddressCacheService.find(12345, with_geocoding: false)  # Ohne Geocoding
#
#   AddressCacheService.clear(12345)  # Cache für eine Adresse löschen
#   AddressCacheService.clear_all     # Kompletten Adress-Cache löschen
#
class AddressCacheService
  CACHE_EXPIRY = 24.hours
  CACHE_PREFIX = "firebird_address_".freeze

  # Nominatim API
  NOMINATIM_URL = "https://nominatim.openstreetmap.org/search".freeze
  USER_AGENT = "MetzDispo/1.0".freeze
  RATE_LIMIT_DELAY = 1.1

  class << self
    # Adresse laden (mit Cache)
    def find(address_nr, with_geocoding: true)
      return nil if address_nr.blank?

      address = Rails.cache.fetch(cache_key(address_nr), expires_in: CACHE_EXPIRY) do
        Rails.logger.debug "AddressCacheService: Loading address #{address_nr} from source"
        load_from_source(address_nr)
      end

      return nil unless address

      # Geocoding hinzufügen wenn gewünscht
      if with_geocoding && address[:lat].nil?
        coords = lookup_coordinates(address[:strasse], address[:plz], address[:ort])
        if coords
          address = address.merge(lat: coords[:lat], lng: coords[:lng])
        end
      end

      address
    end

    # Alias für bessere Lesbarkeit
    def fetch(address_nr, **options)
      find(address_nr, **options)
    end

    # Cache für eine Adresse löschen
    def clear(address_nr)
      Rails.cache.delete(cache_key(address_nr))
    end

    # Kompletten Adress-Cache löschen (bei Bedarf)
    def clear_all
      Rails.cache.delete_matched("#{CACHE_PREFIX}*")
    rescue NotImplementedError
      Rails.logger.warn "AddressCacheService: delete_matched not supported"
    end

    # Mehrere Adressen auf einmal laden (für Performance)
    def find_many(address_nrs, with_geocoding: true)
      return {} if address_nrs.blank?

      address_nrs.uniq.compact.each_with_object({}) do |nr, result|
        result[nr] = find(nr, with_geocoding: with_geocoding)
      end
    end

    # Nur Koordinaten für eine Adresse holen (aus DB-Cache, kein Nominatim)
    def lookup_coordinates(strasse, plz, ort)
      return nil if strasse.blank? && plz.blank? && ort.blank?

      address_string = build_address_string(strasse, plz, ort)
      return nil if address_string.blank?

      address_hash = generate_hash(address_string)

      # Aus DB-Cache lesen
      if defined?(GeocodeCache)
        cached = GeocodeCache.find_by(address_hash: address_hash)
        if cached&.found?
          Rails.logger.debug "GeocodeCache HIT: #{address_string}"
          return cached.coordinates
        end
      end

      # Kein Nominatim-Aufruf vom Server - Frontend macht das Geocoding
      nil
    end

    # Geocoding-Statistik
    def geocode_stats
      return {} unless defined?(GeocodeCache)

      {
        total: GeocodeCache.count,
        found: GeocodeCache.where(found: true).count,
        not_found: GeocodeCache.where(found: false).count
      }
    end

    private

    def cache_key(address_nr)
      "#{CACHE_PREFIX}#{address_nr}"
    end

    def load_from_source(address_nr)
      if use_direct_connection?
        load_from_firebird(address_nr)
      else
        load_from_api(address_nr)
      end
    end

    def use_direct_connection?
      defined?(Firebird::Connection) && Firebird::Connection.instance.present?
    rescue
      false
    end

    # ============================================
    # PRODUCTION: Direkte Firebird-Verbindung
    # ============================================

    def load_from_firebird(address_nr)
      return nil unless defined?(Firebird::Connection)

      conn = Firebird::Connection.instance
      rows = conn.query("SELECT * FROM ADRESSEN WHERE NUMMER = #{address_nr.to_i}")

      return nil if rows.empty?

      row = rows.first
      build_address_hash(
        name1: row["NAME1"],
        name2: row["NAME2"],
        strasse: row["STRASSE"],
        plz: row["PLZ"],
        ort: row["ORT"],
        land: row["LAND"],
        telefon1: row["TELEFON1"],
        telefon2: row["TELEFON2"],
        telefax: row["TELEFAX"],
        email: row["EMAIL"]
      )
    rescue => e
      Rails.logger.warn "AddressCacheService: Firebird error for #{address_nr}: #{e.message}"
      nil
    end

    # ============================================
    # DEVELOPMENT: HTTP API Verbindung
    # ============================================

    def load_from_api(address_nr)
      return nil unless defined?(FirebirdConnectApi)

      response = FirebirdConnectApi.get("/addresses/#{address_nr}")

      return nil unless response.success?

      parsed = JSON.parse(response.body)
      data = parsed["data"]

      return nil unless data

      build_address_hash(
        name1: data["name_1"],
        name2: data["name_2"],
        strasse: data["street"],
        plz: data["postal_code"],
        ort: data["city"],
        land: data["country"],
        telefon1: data["phone_1"],
        telefon2: data["phone_2"],
        telefax: data["fax"],
        email: data["email"]
      )
    rescue => e
      Rails.logger.warn "AddressCacheService: API error for #{address_nr}: #{e.message}"
      nil
    end

    # ============================================
    # Geocoding
    # ============================================

    def build_address_string(strasse, plz, ort)
      clean_strasse = clean_street_for_geocoding(strasse)
      clean_ort = clean_city_name(ort)

      parts = []
      parts << clean_strasse if clean_strasse.present?
      parts << "#{plz} #{clean_ort}".strip if plz.present? || clean_ort.present?

      parts.join(", ").strip
    end

    def clean_street_for_geocoding(strasse)
      return "" if strasse.blank?

      strasse.to_s
             .gsub(/,?\s*OT\s+[^,]+/i, "")   # ", OT Bühl" entfernen
             .gsub(/\s*-\s*OT\s+[^,]+/i, "") # "- OT Riesbürg" entfernen
             .gsub(/\s+/, " ")
             .strip
    end

    def clean_city_name(ort)
      return "" if ort.blank?

      ort.to_s
         .gsub(/,?\s*OT\s+[^,]+/i, "")   # ", OT Bühl" entfernen (mit Umlauten)
         .gsub(/\s*-\s*OT\s+[^,]+/i, "") # "- OT Riesbürg" entfernen
         .gsub(/\s+/, " ")
         .strip
    end

    def generate_hash(address_string)
      Digest::MD5.hexdigest(address_string.downcase.strip)
    end

    def fetch_and_cache_coordinates(address_string, address_hash)
      coords = call_nominatim(address_string)

      # In DB speichern wenn GeocodeCache verfügbar
      if defined?(GeocodeCache)
        GeocodeCache.create!(
          address_hash: address_hash,
          address_string: address_string,
          lat: coords&.dig(:lat),
          lng: coords&.dig(:lng),
          found: coords.present?,
          source: "nominatim"
        )
      end

      coords
    rescue ActiveRecord::RecordNotUnique
      # Race condition - anderer Prozess hat bereits gespeichert
      cached = GeocodeCache.find_by(address_hash: address_hash)
      cached&.coordinates
    rescue => e
      Rails.logger.error "AddressCacheService geocode error: #{e.message}"
      nil
    end

    def call_nominatim(address_string)
      # Rate limiting
      @last_request_at ||= nil
      if @last_request_at && (Time.current - @last_request_at) < RATE_LIMIT_DELAY
        sleep(RATE_LIMIT_DELAY)
      end
      @last_request_at = Time.current

      uri = URI(NOMINATIM_URL)
      uri.query = URI.encode_www_form(
        format: "json",
        q: address_string,
        limit: 1,
        countrycodes: "de"
      )

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)

        if data.is_a?(Array) && data.any?
          {
            lat: data[0]["lat"].to_f,
            lng: data[0]["lon"].to_f
          }
        else
          Rails.logger.warn "Nominatim: No results for '#{address_string}'"
          nil
        end
      else
        Rails.logger.error "Nominatim error: #{response.code} - #{response.body}"
        nil
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error "Nominatim timeout: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Nominatim error: #{e.message}"
      nil
    end

    # ============================================
    # Helper
    # ============================================

    def build_address_hash(attrs)
      {
        name1: clean_string(attrs[:name1]),
        name2: clean_string(attrs[:name2]),
        strasse: clean_string(attrs[:strasse]),
        plz: clean_string(attrs[:plz]),
        ort: clean_string(attrs[:ort]),
        land: clean_string(attrs[:land]),
        telefon1: clean_string(attrs[:telefon1]),
        telefon2: clean_string(attrs[:telefon2]),
        telefax: clean_string(attrs[:telefax]),
        email: clean_string(attrs[:email]),
        lat: nil,
        lng: nil
      }
    end

    def clean_string(value)
      return nil if value.nil?

      str = value.to_s

      # Firebird liefert UTF-8 Daten aber als ASCII-8BIT markiert
      if str.encoding == Encoding::ASCII_8BIT
        str = str.force_encoding("UTF-8")
      end

      # Ungültige Bytes ersetzen falls vorhanden
      str = str.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") unless str.valid_encoding?

      str.strip.presence
    rescue
      value.to_s.strip.presence
    end
  end
end
