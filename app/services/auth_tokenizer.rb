class AuthTokenizer
  def self.new_token(time = nil)
    t = (t || Time.current).to_i
    "#{t}-" + SecureRandom.hex + Digest::MD5.hexdigest("#{SecureRandom.hex}-#{t}")
  end
end
