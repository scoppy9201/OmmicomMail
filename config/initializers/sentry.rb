# frozen_string_literal: true

require "ommicom_mail/config"

if OmmicomMail::Config.logging.sentry_dsn
  Sentry.init do |config|
    config.dsn = OmmicomMail::Config.logging.sentry_dsn
  end
end
