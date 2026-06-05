# frozen_string_literal: true

class SessionsController < ApplicationController

  layout "sub"

  before_action :require_local_authentication, only: [:create, :begin_password_reset, :finish_password_reset]
  skip_before_action :login_required, only: [:new, :create, :begin_password_reset, :finish_password_reset, :ip, :raise_error, :create_from_oidc, :oauth_failure]

  def create
    login(User.authenticate(params[:email_address], params[:password]))
    flash[:remember_login] = true
    redirect_to_with_return_to root_path
  rescue OmmicomMail::Errors::AuthenticationError
    flash.now[:alert] = "Thông tin đăng nhập không đúng. Vui lòng kiểm tra và thử lại."
    render "new"
  end

  def destroy
    auth_session.invalidate! if logged_in?
    reset_session
    redirect_to login_path
  end

  def persist
    auth_session.persist! if logged_in?
    render plain: "OK"
  end

  def begin_password_reset
    return unless request.post?

    user_scope = OmmicomMail::Config.oidc.enabled? ? User.with_password : User
    user = user_scope.find_by(email_address: params[:email_address])

    if user.nil?
      redirect_to login_reset_path(return_to: params[:return_to]), alert: "Không tìm thấy người dùng cục bộ với địa chỉ email này. Vui lòng kiểm tra và thử lại."
      return
    end

    user.begin_password_reset(params[:return_to])
    redirect_to login_path(return_to: params[:return_to]), notice: "Vui lòng kiểm tra email và nhấp vào liên kết hệ thống đã gửi."
  end

  def finish_password_reset
    @user = User.where(password_reset_token: params[:token]).where("password_reset_token_valid_until > ?", Time.now).first
    if @user.nil?
      redirect_to login_path(return_to: params[:return_to]), alert: "Liên kết này đã hết hạn hoặc không tồn tại. Vui lòng chọn đặt lại mật khẩu để thử lại."
    end

    return unless request.post?

    if params[:password].blank?
      flash.now[:alert] = "Bạn cần nhập mật khẩu mới."
      return
    end

    @user.password = params[:password]
    @user.password_confirmation = params[:password_confirmation]
    return unless @user.save

    login(@user)
    redirect_to_with_return_to root_path, notice: "Mật khẩu mới đã được đặt và bạn đã đăng nhập."
  end

  def ip
    render plain: "ip: #{request.ip} remote ip: #{request.remote_ip}"
  end

  def create_from_oidc
    unless OmmicomMail::Config.oidc.enabled?
      raise OmmicomMail::Error, "Không thể dùng OIDC khi chưa bật trong cấu hình"
    end

    auth = request.env["omniauth.auth"]
    user = User.find_from_oidc(auth.extra.raw_info, logger: OmmicomMail.logger)
    if user.nil?
      redirect_to login_path, alert: "Không tìm thấy người dùng khớp với danh tính của bạn. Vui lòng liên hệ quản trị viên."
      return
    end

    login(user)
    flash[:remember_login] = true
    redirect_to_with_return_to root_path
  end

  def oauth_failure
    redirect_to login_path, alert: "Đã xảy ra sự cố khi đăng nhập bằng OpenID. Vui lòng thử lại sau hoặc liên hệ quản trị viên."
  end

  private

  def require_local_authentication
    return if OmmicomMail::Config.oidc.local_authentication_enabled?

    redirect_to login_path, alert: "Xác thực cục bộ chưa được bật."
  end

end
