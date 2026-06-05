# frozen_string_literal: true

require "resolv"

module HasDNSChecks

  def dns_ok?
    spf_status == "OK" && dkim_status == "OK" && %w[OK Missing].include?(mx_status) && %w[OK Missing].include?(return_path_status)
  end

  def dns_checked?
    spf_status.present?
  end

  def check_dns(source = :manual)
    check_spf_record
    check_dkim_record
    check_mx_records
    check_return_path_record
    self.dns_checked_at = Time.now
    save!
    if source == :auto && !dns_ok? && owner.is_a?(Server)
      WebhookRequest.trigger(owner, "DomainDNSError", {
        server: owner.webhook_hash,
        domain: name,
        uuid: uuid,
        dns_checked_at: dns_checked_at.to_f,
        spf_status: spf_status,
        spf_error: spf_error,
        dkim_status: dkim_status,
        dkim_error: dkim_error,
        mx_status: mx_status,
        mx_error: mx_error,
        return_path_status: return_path_status,
        return_path_error: return_path_error
      })
    end
    dns_ok?
  end

  #
  # SPF
  #

  def check_spf_record
    result = resolver.txt(name)
    spf_records = result.grep(/\Av=spf1/)
    if spf_records.empty?
      self.spf_status = "Missing"
      self.spf_error = "Tên miền này chưa có bản ghi SPF."
    else
      suitable_spf_records = spf_records.grep(/include:\s*#{Regexp.escape(OmmicomMail::Config.dns.spf_include)}/)
      if suitable_spf_records.empty?
        self.spf_status = "Invalid"
        self.spf_error = "Đã có bản ghi SPF nhưng chưa bao gồm #{OmmicomMail::Config.dns.spf_include}."
        false
      else
        self.spf_status = "OK"
        self.spf_error = nil
        true
      end
    end
  end

  def check_spf_record!
    check_spf_record
    save!
  end

  #
  # DKIM
  #

  def check_dkim_record
    domain = "#{dkim_record_name}.#{name}"
    records = resolver.txt(domain)
    if records.empty?
      self.dkim_status = "Missing"
      self.dkim_error = "Không tìm thấy bản ghi TXT cho #{domain}."
    else
      sanitised_dkim_record = records.first.strip.ends_with?(";") ? records.first.strip : "#{records.first.strip};"
      if records.size > 1
        self.dkim_status = "Invalid"
        self.dkim_error = "Có #{records.size} bản ghi tại #{domain}. Chỉ nên có một bản ghi."
      elsif sanitised_dkim_record != dkim_record
        self.dkim_status = "Invalid"
        self.dkim_error = "Bản ghi DKIM tại #{domain} không khớp với bản ghi hệ thống cung cấp. Vui lòng kiểm tra lại nội dung đã sao chép."
      else
        self.dkim_status = "OK"
        self.dkim_error = nil
        true
      end
    end
  end

  def check_dkim_record!
    check_dkim_record
    save!
  end

  #
  # MX
  #

  def check_mx_records
    records = resolver.mx(name).map(&:last)
    if records.empty?
      self.mx_status = "Missing"
      self.mx_error = "Không có bản ghi MX cho #{name}."
    else
      missing_records = OmmicomMail::Config.dns.mx_records.dup - records.map { |r| r.to_s.downcase }
      if missing_records.empty?
        self.mx_status = "OK"
        self.mx_error = nil
      elsif missing_records.size == OmmicomMail::Config.dns.mx_records.size
        self.mx_status = "Missing"
        self.mx_error = "Tên miền có bản ghi MX nhưng không có bản ghi nào trỏ về hệ thống."
      else
        self.mx_status = "Invalid"
        self.mx_error = "Thiếu bản ghi MX bắt buộc cho #{missing_records.to_sentence}."
      end
    end
  end

  def check_mx_records!
    check_mx_records
    save!
  end

  #
  # Return Path
  #

  def check_return_path_record
    records = resolver.cname(return_path_domain)
    if records.empty?
      self.return_path_status = "Missing"
      self.return_path_error = "Chưa có bản ghi return path tại #{return_path_domain}."
    elsif records.size == 1 && records.first == OmmicomMail::Config.dns.return_path_domain
      self.return_path_status = "OK"
      self.return_path_error = nil
    else
      self.return_path_status = "Invalid"
      self.return_path_error = "Có bản ghi CNAME tại #{return_path_domain} nhưng đang trỏ tới #{records.first}, giá trị này chưa đúng. Bản ghi cần trỏ tới #{OmmicomMail::Config.dns.return_path_domain}."
    end
  end

  def check_return_path_record!
    check_return_path_record
    save!
  end

end

# -*- SkipSchemaAnnotations
