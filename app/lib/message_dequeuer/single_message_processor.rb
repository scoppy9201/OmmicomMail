# frozen_string_literal: true

module MessageDequeuer
  class SingleMessageProcessor < Base

    def process
      catch_stops do
        check_message_exists
        check_server_suspension
        check_delivery_attempts
        check_raw_message_exists

        processor = nil
        case queued_message.message.scope
        when "incoming"
          processor = IncomingMessageProcessor
        when "outgoing"
          processor = OutgoingMessageProcessor
        else
          create_delivery "HardFail", details: "Scope #{queued_message.message.scope} không hợp lệ"
          remove_from_queue
          stop_processing
        end

        processor.process(queued_message, logger: @logger, state: @state)
      end
    rescue StandardError => e
      handle_exception(e)
    end

    private

    def check_message_exists
      return if queued_message.message

      log "unqueueing because backend message has been removed"
      remove_from_queue
      stop_processing
    end

    def check_server_suspension
      return unless queued_message.server.suspended?

      log "server is suspended, holding message"
      create_delivery "Held", details: "Máy chủ mail đã bị tạm ngưng. Hiện không thể xử lý email. Vui lòng liên hệ hỗ trợ."
      remove_from_queue
      stop_processing
    end

    def check_delivery_attempts
      return if queued_message.attempts < OmmicomMail::Config.postal.default_maximum_delivery_attempts

      details = "Đã đạt số lần thử chuyển phát tối đa (#{queued_message.attempts})."
      if queued_message.message.scope == "incoming"
        # Send bounces to incoming e-mails when they are hard failed
        if bounce_id = queued_message.send_bounce
          details += " Email bounce đã được gửi tới người gửi (xem email <msg:#{bounce_id}>)."
        end
      elsif queued_message.message.scope == "outgoing"
        # Add the recipient to the suppression list
        if queued_message.server.message_db.suppression_list.add(:recipient, queued_message.message.rcpt_to, reason: "too many soft fails")
          log "added #{queued_message.message.rcpt_to} to suppression list because maximum attempts has been reached"
          details += " Đã thêm #{queued_message.message.rcpt_to} vào danh sách chặn gửi vì chuyển phát thất bại #{queued_message.attempts} lần."
        end
      end

      log "message has reached maximum number of attempts, hard failing"
      create_delivery "HardFail", details: details
      remove_from_queue
      stop_processing
    end

    def check_raw_message_exists
      return if queued_message.message.raw_message?

      log "raw message has been removed, not sending"
      create_delivery "HardFail", details: "Email gốc đã bị xóa. Không thể gửi email."
      remove_from_queue
      stop_processing
    end

  end
end
