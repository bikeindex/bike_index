class SecurityTokenizer
  EARLIEST_TOKEN_TIME = 1427848192 # 2015-03-31T17:29:52

  def self.new_token(time = nil)
    t = (time.presence || Time.current).to_i
    "#{t}-" + SecureRandom.hex + Digest::MD5.hexdigest("#{SecureRandom.hex}-#{t}")
  end

  # Passwords have to be less than 72 characters. Lazy hack
  def self.new_password_token(time = nil)
    new_token(time).slice(0, 60)
  end

  # Because of texting length concerns, use an abbreviated token
  def self.new_short_token
    new_token.split("-")[1].slice(2, 21)
  end

  def self.token_time(str)
    t, toke = str.to_s.split("-")
    t = (t.present? && toke.present? && t.to_i > EARLIEST_TOKEN_TIME) ? t.to_i : EARLIEST_TOKEN_TIME
    Time.at(t)
  end
end
