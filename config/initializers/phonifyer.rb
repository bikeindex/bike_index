class Phonifyer
  def self.phonify(string)
    if string.strip[/\A\+/]
      cc = string.strip[/\A\+\d*/]
      "#{cc} #{string.strip.gsub(cc, '').gsub(/\D/, '')}"
    else
      string.strip.gsub(/\D/, '')
    end
  end

  def self.display(string)
    str = phonify(string)
    end_num = str[/\d*\z/]
    # Split at 3rd character, again 3 characters later, again with all the chars
    formatted = [3, 3, 10].each_with_index.collect do |amount, index|
      end_num[(index * 3), amount]
    end.join('.')
    [str[/\A\+\d*/], formatted].reject(&:blank?).join(' ')
  end
end
