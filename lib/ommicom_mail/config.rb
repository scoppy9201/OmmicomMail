# frozen_string_literal: true

require_relative "../postal/config"

OmmicomMail = Postal unless Object.const_defined?(:OmmicomMail)
