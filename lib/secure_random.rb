module SecureRandom
  class << self
    def create_accept_id
      time = Time.now

      change_num_to_char(time.strftime("%M")) + SecureRandom.alphanumeric(1) +
      change_num_to_char(time.strftime("%H")) + SecureRandom.alphanumeric(1) +
      change_num_to_char(time.strftime("%d")) + SecureRandom.alphanumeric(1)
    end

    private

    def change_num_to_char(str)
      n = rand(3)

      case n
      when 0
        str.gsub('0', 'C').gsub('1', 'f').gsub('2', 'R').gsub('3', 'v').gsub('4', 'B')
           .gsub('5', 'm').gsub('6', 'W').gsub('7', 'h').gsub('8', 'u').gsub('9', 'z')
      when 1
        str.gsub('0', 'B').gsub('1', 'q').gsub('2', 'G').gsub('3', 'p').gsub('4', 'S')
           .gsub('5', 'x').gsub('6', 'Q').gsub('7', 'e').gsub('8', 'k').gsub('9', 'w')
      when 2
        str.gsub('0', 'D').gsub('1', 'i').gsub('2', 'T').gsub('3', 'r').gsub('4', 'A')
           .gsub('5', 'y').gsub('6', 'Z').gsub('7', 'c').gsub('8', 's').gsub('9', 'j')
      end
    end
  end
end