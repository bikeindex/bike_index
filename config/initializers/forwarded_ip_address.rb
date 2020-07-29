class ForwardedIpAddress
  def self.parse(request)
    addy = request.env["HTTP_CF_CONNECTING_IP"]
    addy ||= request.env["HTTP_X_FORWARDED_FOR"].split(",").last if request.env["HTTP_X_FORWARDED_FOR"].present?
    addy || request.env["REMOTE_ADDR"] || request.env["ip"]
  end
end
