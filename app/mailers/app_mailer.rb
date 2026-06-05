# frozen_string_literal: true

class AppMailer < ApplicationMailer

  def verify_domain(domain, email_address, user)
    @domain = domain
    @email_address = email_address
    @user = user
    mail to: email_address, subject: "Xác minh quyền sở hữu #{@domain.name}"
  end

  def password_reset(user, return_to = nil)
    @user = user
    @return_to = return_to
    mail to: @user.email_address, subject: "Đặt lại mật khẩu OmmicomMail"
  end

  def server_send_limit_approaching(server)
    @server = server
    mail to: @server.organization.notification_addresses, subject: "[#{server.full_permalink}] Máy chủ mail sắp đạt giới hạn gửi"
  end

  def server_send_limit_exceeded(server)
    @server = server
    mail to: @server.organization.notification_addresses, subject: "[#{server.full_permalink}] Máy chủ mail đã vượt quá giới hạn gửi"
  end

  def server_suspended(server)
    @server = server
    mail to: @server.organization.notification_addresses, subject: "[#{server.full_permalink}] Máy chủ mail đã bị tạm ngưng"
  end

  def test_message(recipient)
    mail to: recipient, subject: "Email kiểm tra SMTP từ OmmicomMail"
  end

end
