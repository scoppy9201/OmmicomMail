# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base

  default from: "#{OmmicomMail::Config.smtp.from_name} <#{OmmicomMail::Config.smtp.from_address}>"
  layout false

end
