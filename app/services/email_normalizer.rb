class EmailNormalizer
  def initialize(email=nil)
    @email = email || ''
  end

  def normalized
    @email.strip.downcase
  end
end