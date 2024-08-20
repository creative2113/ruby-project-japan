# USAGE
#   stub = StabMaker.new({:[] => false, :id => 123 })
#   stub['error'] # => false
#   stub.id       # => 123

class StabMaker
  def initialize(methods)
    methods.each do |key, value|
      self.class.define_method(key) do |arg = nil|
         value
      end
    end
  end
end
