# frozen_string_literal: true

ENV["SILENCE_OMMICOMMAIL_CONFIG_MESSAGES"] = "true"
require File.expand_path("../lib/ommicom_mail/config", __dir__)
puts OmmicomMail.rp_dkim_dns_record
