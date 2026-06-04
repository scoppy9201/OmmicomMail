# frozen_string_literal: true

require_relative "../lib/ommicom_mail/config"

threads_count = OmmicomMail::Config.web_server.max_threads
threads         threads_count, threads_count
bind_address  = ENV.fetch("BIND_ADDRESS", OmmicomMail::Config.web_server.default_bind_address)
bind_port     = ENV.fetch("PORT", OmmicomMail::Config.web_server.default_port)
bind            "tcp://#{bind_address}:#{bind_port}"
environment     OmmicomMail::Config.rails.environment || "development"
prune_bundler
quiet false
