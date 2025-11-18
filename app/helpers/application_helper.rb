module ApplicationHelper
  # app/helpers/flash_helper.rb

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
end
