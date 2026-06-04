# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

require_relative "../config/environment"

HealthServer.start(
  name: "smtp-server",
  default_port: OmmicomMail::Config.smtp_server.default_health_server_port,
  default_bind_address: OmmicomMail::Config.smtp_server.default_health_server_bind_address
)
SMTPServer::Server.new(debug: true).run
