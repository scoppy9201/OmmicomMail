# frozen_string_literal: true

class UsersController < ApplicationController

  before_action :admin_required
  before_action { params[:id] && @user = User.find_by!(uuid: params[:id]) }

  def index
    @users = User.order(:first_name, :last_name).includes(:organization_users)
  end

  def new
    @user = User.new(admin: true)
  end

  def edit
  end

  def create
    @user = User.new(params.require(:user).permit(:email_address, :first_name, :last_name, :password, :password_confirmation, :admin, organization_ids: []))
    if @user.save
      redirect_to_with_json :users, notice: "#{@user.name} đã được tạo thành công."
    else
      render_form_errors "new", @user
    end
  end

  def update
    @user.attributes = params.require(:user).permit(:email_address, :first_name, :last_name, :admin, organization_ids: [])

    if @user == current_user && !@user.admin?
      respond_to do |wants|
        wants.html { redirect_to users_path, alert: "Bạn không thể tự thay đổi quyền admin của chính mình." }
        wants.json { render json: { form_errors: ["Bạn không thể tự thay đổi quyền admin của chính mình."] }, status: :unprocessable_entity }
      end
      return
    end

    if @user.save
      redirect_to_with_json :users, notice: "Quyền của #{@user.name} đã được cập nhật thành công."
    else
      render_form_errors "edit", @user
    end
  end

  def destroy
    if @user == current_user
      redirect_to_with_json :users, alert: "Bạn không thể xóa chính tài khoản của mình."
      return
    end

    @user.destroy!
    redirect_to_with_json :users, notice: "#{@user.name} đã được xóa."
  end

end
