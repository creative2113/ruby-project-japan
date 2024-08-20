class DynamoDb

  def initialize(key, new_items = {})
    raise 'Second argument should be Hash.' unless new_items.class == Hash

    @client    = Aws::DynamoDB::Client.new
    @new_items = check_new_items(new_items)
    @items     = nil
    @exist     = nil
  end

  def add_new_item(new_items)
    raise 'Argument should be Hash.' unless new_items.class == Hash

    @new_items.merge!(check_new_items(new_items))
  end

  def exist?
    get if @exist.nil?
    @exist
  end

  def get

    params = {
      table_name: self.class::TABLE,
      key: @key
    }
    result = @client.get_item(params)

    # レコードが取れないときはnilが返る
    @exist = result[:item].nil? ? false : true

    @items = result[:item] if @exist

    self
  rescue  Aws::DynamoDB::Errors::ServiceError => e
    puts "[DynamoDB Error][#get] Unable to read item:"
    puts "#{e.message}"
    Lograge.logging('error', { class: 'DynamoDb', method: 'get', issue: "Unable to read item", table: self.class::TABLE, key: @key, err_msg: e.message, backtrace: e.backtrace})
    nil
  end

  def create(new_items = {}, reget = false)

    get if @exist.nil? || reget

    return update(:all, new_items) if @exist

    add_new_item(new_items)

    item = @key

    item = item.merge(@new_items)

    params = {
        table_name: self.class::TABLE,
        item: item
    }

    @client.put_item(params)

    @new_items = {}

    true
  rescue  Aws::DynamoDB::Errors::ServiceError => e
    puts "[DynamoDB Error][#create] Unable to add item:"
    puts "#{e.message}"
    Lograge.logging('error', { class: 'DynamoDb', method: 'create', issue: "Unable to add item", table: self.class::TABLE, key: @key, err_msg: e.message, backtrace: e.backtrace})
    false
  end

  def update(update_attributes = :all, new_items = {})

    add_new_item(new_items)

    update_attributes = check_update_attributes(update_attributes)

    raise 'update_attributes is empty.' if update_attributes.empty?

    params = {
      table_name: self.class::TABLE,
      key: @key,
      update_expression: make_update_expression(update_attributes),
      expression_attribute_values: make_expression_attribute_values(update_attributes),
      return_values: "UPDATED_NEW"
    }

    params.merge!(make_expression_attribute_names(update_attributes)) if include_reserved_word?(update_attributes)

    @client.update_item(params)

    @new_items = {}

    get

    true
  rescue  Aws::DynamoDB::Errors::ServiceError => e
    puts "[DynamoDB Error][#update] Unable to add item:"
    puts "#{e.message}"
    Lograge.logging('error', { class: 'DynamoDb', method: 'update', issue: "Unable to add item", table: self.class::TABLE, key: @key, err_msg: e.message, backtrace: e.backtrace})
    false
  end

  private

  def set_key_value(key_v)
    @key = { self.class::PRIMARY_KEY => key_v }
  end

  def check_new_items(new_items)
    true_items = {}

    new_items.each do |k, v|
      next unless self.class::ITEMS.include?(k.to_s)

      unless %w(String Hash Array Set Numeric Integer Float TrueClass FalseClass NilClass).include?(v.class.to_s)
        v = v.to_s
      end

      v = v if self.class::CHANGE_STR_COL.include?(k.to_s)

      true_items.store(k, v) unless v == ''
    end

    true_items
  end

  def check_update_attributes(update_attributes)
    return @new_items.keys if update_attributes == :all

    unless update_attributes.class == Array
      raise 'update_attributes should be :all symbol or array.'
    end

    true_attr = []
    update_attributes.each do |att|
      true_attr << att if self.class::ITEMS.include?(att.to_s)
    end

    true_attr
  end

  def make_update_expression(update_attributes)
    reserved_words = self.class::RESERVED_WORDS

    str = 'set '
    update_attributes.each do |att|
      tmp_att = reserved_words.keys.include?(att.to_s) ? reserved_words[att.to_s] : att

      str = str + "#{tmp_att} = :#{att}, "
    end

    str.strip.chop
  end

  def make_expression_attribute_values(update_attributes)

    h = {}
    update_attributes.each do |att|
      h.store(":#{att.to_s}", @new_items.stringify_keys[att.to_s])
    end

    h
  end

  # DynamoDbの予約語をチェックする
  def make_expression_attribute_names(update_attributes)
    reserved_words = self.class::RESERVED_WORDS

    h = {}

    update_attributes.each do |att|
      if reserved_words.keys.include?(att.to_s)
        h.store(reserved_words[att.to_s], att.to_s)
      end
    end

    { expression_attribute_names: h }
  end

  def include_reserved_word?(update_attributes)
    update_attributes.each do |att|
      return true if self.class::RESERVED_WORDS.keys.include?(att.to_s)
    end
    false
  end

  def get_test_env_num
    return '' unless ENV['RAILS_ENV'] == 'test'
    if ENV['TEST_ENV_NUMBER'].nil?
      '1'
    else
      ENV['TEST_ENV_NUMBER'].to_s
    end
  end

  class << self
    def get_count
      client = Aws::DynamoDB::Client.new

      params = {
        table_name: self::TABLE,
        select: 'COUNT'
      }

      begin
        res = client.scan(params)

        res.count
      rescue Aws::DynamoDB::Errors::ServiceError => e
        puts "[DynamoDB Error][#get_count] Unable to get count"
        puts "#{e.message}"
        Lograge.logging('error', { class: 'DynamoDb', method: 'get_count', issue: "Unable to get count", table: self::TABLE, err_msg: e.message, backtrace: e.backtrace})
        nil
      end
    end

    def delete_items(keys = [])
      return false if keys.empty?
      return false unless ENV['RAILS_ENV'] == 'development' ||
                          ENV['RAILS_ENV'] == 'test'

      client = Aws::DynamoDB::Client.new

      success = []
      failed  = []

      keys.each do |key|

        params = {
          table_name: self::TABLE,
          key: { self::PRIMARY_KEY => key }
        }

        begin
          client.delete_item(params)

          success << key
        rescue  Aws::DynamoDB::Errors::ServiceError => e
          puts "[DynamoDB Error][#delete_items] Unable to delete item: #{key}"
          puts "#{e.message}"
          Lograge.logging('error', { class: 'DynamoDb', method: 'delete_items', issue: "Unable to delete item", table: self::TABLE, key: key, err_msg: e.message, backtrace: e.backtrace})
          failed << key
        end
      end

      puts "Deleted Fail: #{failed.join(', ')}" if failed.count > 0

      failed.size > 0 ? false : true
    end

    # テスト用のデータを作成する
    def create(registered_symbol_or_items = {}, items = {})
      return false unless registered_symbol_or_items.class == Symbol ||
                          registered_symbol_or_items.class == Hash
      return false unless items.class == Hash

      params = {}

      params.merge!(get_params)

      if registered_symbol_or_items.class == Symbol
        params.merge!(get_params(registered_symbol_or_items))
      elsif registered_symbol_or_items.class == Hash
        params.merge!(registered_symbol_or_items)
      end

      params.merge!(items)

      pk = params[self::PRIMARY_KEY]

      params.delete(self::PRIMARY_KEY)

      td = new(pk, params)
      td.create
      td.get
    end

    private

    def get_params(symbol = :normal)
      case symbol
      when :normal
        {}
      else
        raise 'No Test Data Sample.'
      end
    end
  end
end