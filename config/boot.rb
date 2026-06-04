# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

require_relative "../lib/ommicom_mail/config"

ENV["RAILS_ENV"] = OmmicomMail::Config.rails.environment || "development"
