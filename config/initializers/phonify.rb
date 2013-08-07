class Phonifyer
  def self.phonify(string)
    string.gsub(/\D/,'')
  end
end