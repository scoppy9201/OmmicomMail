# frozen_string_literal: true

class BounceMessage

  def initialize(server, message)
    @server = server
    @message = message
  end

  def raw_message
    mail = Mail.new
    mail.to = @message.mail_from
    mail.from = "Dịch vụ chuyển phát mail <#{@message.route.description}>"
    mail.subject = "Chuyển phát email thất bại (#{@message.subject})"
    mail.text_part = body
    mail.attachments["Email goc.eml"] = { mime_type: "message/rfc822", encoding: "quoted-printable", content: @message.raw_message }
    mail.message_id = "<#{SecureRandom.uuid}@#{OmmicomMail::Config.dns.return_path_domain}>"
    mail.to_s
  end

  def queue
    message = @server.message_db.new_message
    message.scope = "outgoing"
    message.rcpt_to = @message.mail_from
    message.mail_from = @message.route.description
    message.domain_id = @message.domain&.id
    message.raw_message = raw_message
    message.bounce = true
    message.bounce_for_id = @message.id
    message.save
    message.id
  end

  def postmaster_address
    @server.postmaster_address || "postmaster@#{@message.domain&.name || OmmicomMail::Config.postal.web_hostname}"
  end

  private

  def body
    <<~BODY
      Đây là dịch vụ chuyển phát mail chịu trách nhiệm gửi email tới #{@message.route.description}.

      Email bạn đã gửi không thể chuyển phát. Email gốc được đính kèm trong thư này.

      Nếu cần hỗ trợ thêm, vui lòng liên hệ #{postmaster_address}. Hãy gửi kèm các thông tin bên dưới để chúng tôi xác định sự cố.

      Token email: #{@message.token}@#{@server.token}
      Message ID gốc: #{@message.message_id}
      Người gửi: #{@message.mail_from}
      Người nhận: #{@message.rcpt_to}
    BODY
  end

end
