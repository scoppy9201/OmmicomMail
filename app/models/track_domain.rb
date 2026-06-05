# frozen_string_literal: true

# == Schema Information
#
# Table name: track_domains
#
#  id                     :integer          not null, primary key
#  uuid                   :string(255)
#  server_id              :integer
#  domain_id              :integer
#  name                   :string(255)
#  dns_checked_at         :datetime
#  dns_status             :string(255)
#  dns_error              :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  ssl_enabled            :boolean          default(TRUE)
#  track_clicks           :boolean          default(TRUE)
#  track_loads            :boolean          default(TRUE)
#  excluded_click_domains :text(65535)
#

require "resolv"

class TrackDomain < ApplicationRecord

  include HasUUID

  belongs_to :server
  belongs_to :domain

  validates :name, presence: true, format: { with: /\A[a-z0-9-]+\z/ }, uniqueness: { scope: :domain_id, case_sensitive: false, message: "đã được thêm" }
  validates :domain_id, uniqueness: { scope: :server_id, case_sensitive: false, message: "đã có tracking domain cho máy chủ này" }
  validate :validate_domain_belongs_to_server

  scope :ok, -> { where(dns_status: "OK") }

  after_create :check_dns, unless: :dns_status

  before_validation do
    self.server = domain.server if domain && server.nil?
  end

  def full_name
    "#{name}.#{domain.name}"
  end

  def excluded_click_domains_array
    @excluded_click_domains_array ||= excluded_click_domains ? excluded_click_domains.split("\n").map(&:strip) : []
  end

  def dns_ok?
    dns_status == "OK"
  end

  def check_dns
    records = domain.resolver.cname(full_name)
    if records.empty?
      self.dns_status = "Missing"
      self.dns_error = "Chưa có bản ghi tại #{full_name}."
    elsif records.size == 1 && records.first == OmmicomMail::Config.dns.track_domain
      self.dns_status = "OK"
      self.dns_error = nil
    else
      self.dns_status = "Invalid"
      self.dns_error = "Có bản ghi CNAME tại #{full_name} nhưng đang trỏ tới #{records.first}, giá trị này chưa đúng. Bản ghi cần trỏ tới #{OmmicomMail::Config.dns.track_domain}."
    end
    self.dns_checked_at = Time.now
    save!
    dns_ok?
  end

  def use_ssl?
    ssl_enabled?
  end

  def validate_domain_belongs_to_server
    return unless domain && ![server, server.organization].include?(domain.owner)

    errors.add :domain, "không thuộc máy chủ hoặc tổ chức của máy chủ"
  end

end
