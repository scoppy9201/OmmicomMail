# frozen_string_literal: true

class IPPoolsController < ApplicationController

  before_action :admin_required
  before_action { params[:id] && @ip_pool = IPPool.find_by_uuid!(params[:id]) }

  def index
    @ip_pools = IPPool.order(:name).to_a
  end

  def new
    @ip_pool = IPPool.new
  end

  def create
    @ip_pool = IPPool.new(safe_params)
    if @ip_pool.save
      redirect_to_with_json [:edit, @ip_pool], notice: "IP pool đã được thêm thành công. Bạn có thể thêm địa chỉ IP vào pool này."
    else
      render_form_errors "new", @ip_pool
    end
  end

  def update
    if @ip_pool.update(safe_params)
      redirect_to_with_json [:edit, @ip_pool], notice: "IP pool đã được cập nhật."
    else
      render_form_errors "edit", @ip_pool
    end
  end

  def destroy
    @ip_pool.destroy
    redirect_to_with_json :ip_pools, notice: "IP pool đã được xóa thành công."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to_with_json [:edit, @ip_pool], alert: "Không thể xóa IP pool vì vẫn còn địa chỉ IP hoặc máy chủ liên quan."
  end

  private

  def safe_params
    params.require(:ip_pool).permit(:name, :default)
  end

end
