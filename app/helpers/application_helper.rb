module ApplicationHelper
  # app/helpers/flash_helper.rb
  module FlashHelper
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
  end
end
