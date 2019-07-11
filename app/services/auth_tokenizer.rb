class AuthTokenizer
  def self.new_token(time = nil)
    t = (t || Time.current).to_i
    "#{t}-" + SecureRandom.hex + Digest::MD5.hexdigest("#{SecureRandom.hex}-#{t}")
  end

  def self.token_time(str)
    t = str.to_s.split("-")[0]
    t = (t.present? && t.to_i > 1427848192) ? t.to_i : 1364777722
    Time.at(t)
  end
end
