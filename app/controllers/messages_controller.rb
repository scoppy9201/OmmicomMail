# frozen_string_literal: true

class MessagesController < ApplicationController

  include WithinOrganization

  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @message = @server.message_db.message(params[:id].to_i) }

  def new
    if params[:direction] == "incoming"
      @message = IncomingMessagePrototype.new(@server, request.ip, "web-ui", {})
      @message.from = session[:test_in_from] || current_user.email_tag
      @message.to = @server.routes.order(:name).first&.description
    else
      @message = OutgoingMessagePrototype.new(@server, request.ip, "web-ui", {})
      @message.to = session[:test_out_to] || current_user.email_address
      if domain = @server.domains.verified.order(:name).first
        @message.from = "test@#{domain.name}"
      end
    end
    @message.subject = "Email kiểm tra lúc #{Time.zone.now.to_fs(:long)}"
    @message.plain_body = "Đây là email dùng để kiểm tra quá trình gửi qua OmmicomMail."
  end

  def create
    if params[:direction] == "incoming"
      session[:test_in_from] = params[:message][:from] if params[:message]
      @message = IncomingMessagePrototype.new(@server, request.ip, "web-ui", params[:message])
      @message.attachments = [{ name: "test.txt", content_type: "text/plain", data: "Xin chào!" }]
    else
      session[:test_out_to] = params[:message][:to] if params[:message]
      @message = OutgoingMessagePrototype.new(@server, request.ip, "web-ui", params[:message])
    end
    if result = @message.create_messages
      if result.size == 1
        redirect_to_with_json organization_server_message_path(organization, @server, result.first.last[:id]), notice: "Email đã được đưa vào hàng đợi thành công."
      else
        redirect_to_with_json [:queue, organization, @server], notice: "Các email đã được đưa vào hàng đợi thành công."
      end
    else
      respond_to do |wants|
        wants.html do
          flash.now[:alert] = "Không thể gửi email. Vui lòng đảm bảo tất cả trường đã được nhập đầy đủ. #{result.errors.inspect}"
          render "new"
        end
        wants.json do
          render json: { flash: { alert: "Không thể gửi email. Vui lòng kiểm tra tất cả trường đã được nhập đầy đủ." } }
        end
      end

    end
  end

  def outgoing
    @searchable = true
    get_messages("outgoing")
    respond_to do |wants|
      wants.html
      wants.json do
        render json: {
          flash: flash.each_with_object({}) { |(type, message), hash| hash[type] = message },
          region_html: render_to_string(partial: "index", formats: [:html])
        }
      end
    end
  end

  def incoming
    @searchable = true
    get_messages("incoming")
    respond_to do |wants|
      wants.html
      wants.json do
        render json: {
          flash: flash.each_with_object({}) { |(type, message), hash| hash[type] = message },
          region_html: render_to_string(partial: "index", formats: [:html])
        }
      end
    end
  end

  def held
    get_messages("held")
  end

  def deliveries
    render json: { html: render_to_string(partial: "deliveries", locals: { message: @message }) }
  end

  def html_raw
    override_content_security_policy_directives(
      default_src: %w('none'),
      script_src: %w('none'),
      style_src: %w('unsafe-inline'),
      img_src: %w(* data:),
      font_src: %w(*),
      frame_ancestors: %w('self'),
      form_action: %w('none'),
      base_uri: %w('none')
    )
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    render html: @message.html_body_without_tracking_image.html_safe
  end

  def spam_checks
    @spam_checks = @message.spam_checks.sort_by { |s| s["score"] }.reverse
  end

  def attachment
    if @message.attachments.size > params[:attachment].to_i
      attachment = @message.attachments[params[:attachment].to_i]
      send_data attachment.body, content_type: attachment.mime_type, disposition: "download", filename: attachment.filename
    else
      redirect_to attachments_organization_server_message_path(organization, @server, @message.id), alert: "Không tìm thấy tệp đính kèm. Vui lòng chọn tệp trong danh sách bên dưới."
    end
  end

  def download
    if @message.raw_message
      send_data @message.raw_message, filename: "Message-#{organization.permalink}-#{@server.permalink}-#{@message.id}.eml", content_type: "text/plain"
    else
      redirect_to organization_server_message_path(organization, @server, @message.id), alert: "Hệ thống không còn lưu email gốc của email này."
    end
  end

  def retry
    if @message.raw_message?
      if @message.queued_message
        @message.queued_message.retry_now
        flash[:notice] = "Email này sẽ được thử gửi lại trong giây lát."
      elsif @message.held?
        @message.add_to_message_queue(manual: true)
        flash[:notice] = "Email này đã được mở giữ. Hệ thống sẽ thử chuyển phát trong giây lát."
      else
        @message.add_to_message_queue(manual: true)
        flash[:notice] = "Email này sẽ được gửi lại trong giây lát."
      end
    else
      flash[:alert] = "Email này không còn khả dụng."
    end
    redirect_to_with_json organization_server_message_path(organization, @server, @message.id)
  end

  def cancel_hold
    @message.cancel_hold
    redirect_to_with_json organization_server_message_path(organization, @server, @message.id)
  end

  def remove_from_queue
    if @message.queued_message && !@message.queued_message.locked?
      @message.queued_message.destroy
    end
    redirect_to_with_json organization_server_message_path(organization, @server, @message.id)
  end

  def suppressions
    @suppressions = @server.message_db.suppression_list.all_with_pagination(params[:page])
  end

  def activity
    @entries = @message.activity_entries
  end

  private

  def get_messages(scope)
    if scope == "held"
      options = { where: { held: true } }
    else
      options = { where: { scope: scope, spam: false }, order: :timestamp, direction: "desc" }

      if @query = (params[:query] || session["msg_query_#{@server.id}_#{scope}"]).presence
        session["msg_query_#{@server.id}_#{scope}"] = @query
        qs = QueryString.new(@query)
        if qs.empty?
          flash.now[:alert] = "Có vẻ bạn chưa nhập điều kiện lọc nào. Vui lòng kiểm tra lại truy vấn."
        else
          @queried = true
          if qs[:order] == "oldest-first"
            options[:direction] = "asc"
          end

          options[:where][:rcpt_to] = qs[:to] if qs[:to]
          options[:where][:mail_from] = qs[:from] if qs[:from]
          options[:where][:status] = qs[:status] if qs[:status]
          options[:where][:token] = qs[:token] if qs[:token]

          if qs[:msgid]
            options[:where][:message_id] = qs[:msgid]
            options[:where].delete(:spam)
            options[:where].delete(:scope)
          end
          options[:where][:tag] = qs[:tag] if qs[:tag]
          options[:where][:id] = qs[:id] if qs[:id]
          options[:where][:spam] = true if qs[:spam] == "yes" || qs[:spam] == "y"
          if qs[:before] || qs[:after]
            options[:where][:timestamp] = {}
            if qs[:before]
              begin
                options[:where][:timestamp][:less_than] = get_time_from_string(qs[:before]).to_f
              rescue TimeUndetermined
                flash.now[:alert] = "Không thể xác định thời gian cho điều kiện before từ '#{qs[:before]}'"
              end
            end

            if qs[:after]
              begin
                options[:where][:timestamp][:greater_than] = get_time_from_string(qs[:after]).to_f
              rescue TimeUndetermined
                flash.now[:alert] = "Không thể xác định thời gian cho điều kiện after từ '#{qs[:after]}'"
              end
            end
          end
        end
      else
        session["msg_query_#{@server.id}_#{scope}"] = nil
      end
    end

    @messages = @server.message_db.messages_with_pagination(params[:page], options)
  end

  class TimeUndetermined < OmmicomMail::Error; end

  def get_time_from_string(string)
    begin
      if string =~ /\A(\d{2,4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})\z/
        time = Time.new(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(3).to_i, ::Regexp.last_match(4).to_i, ::Regexp.last_match(5).to_i)
      elsif string =~ /\A(\d{2,4})-(\d{2})-(\d{2})\z/
        time = Time.new(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(3).to_i, 0)
      else
        time = Chronic.parse(string, context: :past)
      end
    rescue StandardError
      time = nil
    end

    raise TimeUndetermined, "Couldn't determine a suitable time from '#{string}'" if time.nil?

    time
  end

end
