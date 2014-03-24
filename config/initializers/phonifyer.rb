class Phonifyer
  def self.phonify(string)
    if string.strip[/\A\+/]
      cc = string.strip[/\A\+\d*/]
      "#{cc} #{string.strip.gsub(cc,'').gsub(/\D/,'')}"
    else
      string.strip.gsub(/\D/,'')
    end
  end
end