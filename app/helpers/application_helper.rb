module ApplicationHelper
  FLASH_CLASSES = {
    "notice" => "success",
    "alert" => "danger",
    "warning" => "warning",
    "error" => "danger",
    "success" => "success",
    "info" => "info"
  }.freeze

  def flash_css_class(flash_type)
    FLASH_CLASSES[flash_type.to_s] || "info"
  end
  def active?(val)
    val ? "ja" : "nein"
  end

  def safe_encode(value)
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
