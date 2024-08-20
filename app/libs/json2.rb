class Json2
  def self.parse(source, symbolize: true, options: {})
    return nil if source.nil?
    options[:symbolize_names] = symbolize
    JSON.parse(source, options)
  end
end
