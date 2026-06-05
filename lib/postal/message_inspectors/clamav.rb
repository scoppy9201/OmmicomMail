# frozen_string_literal: true

module Postal
  module MessageInspectors
    class Clamav < MessageInspector

      def inspect_message(inspection)
        raw_message = inspection.message.raw_message

        data = nil
        Timeout.timeout(10) do
          tcp_socket = TCPSocket.new(@config.host, @config.port)
          tcp_socket.write("zINSTREAM\0")
          tcp_socket.write([raw_message.bytesize].pack("N"))
          tcp_socket.write(raw_message)
          tcp_socket.write([0].pack("N"))
          tcp_socket.close_write
          data = tcp_socket.read
        end

        if data && data =~ /\Astream:\s+(.*?)[\s\0]+?/
          if ::Regexp.last_match(1).upcase == "OK"
            inspection.threat = false
            inspection.threat_message = "Không phát hiện mối đe dọa"
          else
            inspection.threat = true
            inspection.threat_message = ::Regexp.last_match(1)
          end
        else
          inspection.threat = false
          inspection.threat_message = "Không thể quét email"
        end
      rescue Timeout::Error
        inspection.threat = false
        inspection.threat_message = "Quá thời gian quét mối đe dọa"
      rescue StandardError => e
        logger.error "Error talking to clamav: #{e.class} (#{e.message})"
        logger.error e.backtrace[0, 5]
        inspection.threat = false
        inspection.threat_message = "Có lỗi khi quét mối đe dọa"
      ensure
        begin
          tcp_socket.close
        rescue StandardError
          nil
        end
      end

    end
  end
end
