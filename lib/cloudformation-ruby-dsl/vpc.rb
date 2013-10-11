module Vpc

  class << self; attr_accessor :raw_metadata_table, :VPC_RECORDS; end

  @raw_metadata_table = '
region          vpc     vpc_id          vpc_cidr         vpc_visibility  zone          zone_suffix  subnet_id        subnet_cidr   

'
  raw_header, *raw_data = raw_metadata_table.strip.split("\n").map { |row| row.strip.split(' ') }
  raw_header = raw_header.map { |s| s.to_sym }
  @VPC_RECORDS = raw_data.map { |row| Hash[raw_header.zip(row)] }

  def self.lookup(key, predicate)
    distinct_values(filter(@VPC_RECORDS, predicate), key, false)
  end

  def self.lookup_list(key, predicate)
    distinct_values(filter(@VPC_RECORDS, predicate), key, true)
  end

  def self.metadata_map(predicate, *keys)
    build_nested_map(filter(@VPC_RECORDS, predicate), keys, false)
  end

  def self.metadata_multimap(predicate, *keys)
    build_nested_map(filter(@VPC_RECORDS, predicate), keys, true)
  end

  def self.metadata_multimap_joined_keys(predicate, joiner_char, *keys)
    mapping = build_nested_map(filter(@VPC_RECORDS, predicate), keys, true)

    depth = 2
    raise("depth must be greater than 2") unless depth >= 2

    temp = mapping.dup
    result = {}
    first_round = temp.size
    first_round.times {
      first = temp.shift
      sec_round = first[1].size
      sec_round.times {
        second = first[1].shift
        new_key = first[0] + joiner_char + second[0]
        result[new_key] = second[1]
      }
    }
    result
  end

  def self.office_cidrs()
    [
        "24.155.144.0/27",    # Bazaarvoice Austin office
        "217.68.253.189/32",  # Bazaarvoice London office
        "64.132.218.184/29",  # Bazaarvoice NY office
        "123.51.122.8/30",    # Bazaarvoice Australia Office
        "206.80.5.2/32",      # Bazaarvoice San Francisco Office
        "216.166.20.0/26",    # Bazaarvoice / Data Foundry (Office 1-29, Lab 30-62)
    ]
  end

  # Given an array of Hash objects, return the subset that match the predicate for all keys in the predicate.
  def self.filter(records, predicate)
    records.select { |record| predicate.all? { |k, v| record[k] == v } }
  end

  def self.build_nested_map(records, path, multi)
    key, *rest = path
    if rest.empty?
      # Build the leaf level of the data structure
      distinct_values(records, key, multi)
    else
      # Return a hash keyed by the distinct values of the first key and values are the result of a
      # recursive invocation of arrange() with the rest of the keys
      result = {}
      records.group_by do |record|
        record[key]
      end.map do |value, group|
        result[value] = build_nested_map(group, rest, multi)
      end
      result
    end
  end

  def self.distinct_values(records, key, multi)
    values = records.map { |record| record[key] }.uniq
    if multi
      # In a multimap the leaf level is a list of string values
      values
    else
      # In a non-multimap the leaf level is a single string value
      raise "Multiple distinct values for the same key '#{key}': #{records.inspect}" if values.length > 1
      values[0]
    end
  end

end
