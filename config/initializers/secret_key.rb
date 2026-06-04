# frozen_string_literal: true

if OmmicomMail::Config.rails.secret_key
  Rails.application.credentials.secret_key_base = OmmicomMail::Config.rails.secret_key
else
  warn "No secret key was specified in the OmmicomMail config file. Using one for just this session"
  Rails.application.credentials.secret_key_base = SecureRandom.hex(128)
end
