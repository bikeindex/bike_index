class SecurityTokenizer
  EARLIEST_TOKEN_TIME = 1427848192 # 2015-03-31T17:29:52

  def self.new_token(time = nil)
    t = (time || Time.current).to_i
    "#{t}-" + SecureRandom.hex + Digest::MD5.hexdigest("#{SecureRandom.hex}-#{t}")
  end

  # Passwords have to be less than 72 characters. Lazy hack
  def self.new_password_token(time = nil)
    new_token(time).slice(12, 50)
  end

  def self.token_time(str)
    t = str.to_s.split("-")[0]
    t = (t.present? && t.to_i > EARLIEST_TOKEN_TIME) ? t.to_i : EARLIEST_TOKEN_TIME
    Time.at(t)
  end
end
