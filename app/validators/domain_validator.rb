class DomainValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value =~ /\//
      record.errors[attribute] << (options[:message] || 'cannot include slash mark')
    end
  end
end