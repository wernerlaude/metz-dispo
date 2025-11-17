Rails.application.configure do
  if Rails.env.development?
    # In Development alles erlauben
    config.content_security_policy do |policy|
      policy.default_src :self, :https, :unsafe_eval
      policy.font_src    :self, :https, :data
      policy.img_src     :self, :https, :data
      policy.object_src  :none
      policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval
      policy.style_src   :self, :https, :unsafe_inline
      policy.connect_src :self, :https  # Erlaubt alle HTTPS-Verbindungen
    end
  else
    # Production strenger
    config.content_security_policy do |policy|
      # ... deine Production-Einstellungen
    end
  end
end
