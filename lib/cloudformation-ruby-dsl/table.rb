require 'detabulator'

# def self.lookup(key, predicate)
#   @@table.get(key, predicate)
# end
#
# def self.lookup_list(key, predicate)
#   @@table.get_list(key, predicate)
# end
#
# def self.metadata_map(predicate, *keys)
#   @@table.get_map(predicate, *keys)
# end
#
# def self.metadata_multimap(predicate, *keys)
#   @@table.get_multimap(predicate, *keys)
# end
#
# def self.load_metadata_table(table_def = nil)
#   table_def ||= 'region vpc vpc_id vpc_cidr vpc_visibility zone zone_suffix subnet_id subnet_cidr'
#   @@table = Table.new table_def
# end
#
# load_metadata_table


class Table
  def self.load(filename)
    self.new File.read filename
  end

  def initialize(table_as_text)
    raw_header, *raw_data = Detabulator.new.detabulate table_as_text
    raw_header = raw_header.map { |s| s.to_sym }
    @records = raw_data.map { |row| Hash[raw_header.zip(row)] }
  end

  # Selects all rows in the table which match the name/value pairs of the predicate object and returns
  # the single distinct value from those rows for the specified key.
  def get(key, predicate)
    distinct_values(filter(@records, predicate), key, false)
  end

  # Selects all rows in the table which match the name/value pairs of the predicate object and returns
  # all distinct values from those rows for the specified key.
  def get_list(key, predicate)
    distinct_values(filter(@records, predicate), key, true)
  end

  # Selects all rows in the table which match the name/value pairs of the predicate object and returns a
  # set of nested maps, where the key for the map at level n is the key at index n in the specified keys,
  # except for the last key in the specified keys which is used to determine the value of the leaf-level map.
  # In the simple case where keys is a list of 2 elements, this returns a map from key[0] to key[1].
  def get_map(predicate, *keys)
    build_nested_map(filter(@records, predicate), keys, false)
  end

  # Selects all rows in the table which match the name/value pairs of the predicate object and returns a
  # set of nested maps, where the key for the map at level n is the key at index n in the specified keys,
  # except for the last key in the specified keys which is used to determine the list of values in the
  # leaf-level map.  In the simple case where keys is a list of 2 elements, this returns a map from key[0]
  # to a list of values for key[1].
  def get_multimap(predicate, *keys)
    build_nested_map(filter(@records, predicate), keys, true)
  end

  private

  # Given an array of Hash objects, return the subset that match the predicate for all keys in the predicate.
  def filter(records, predicate)
    records.select { |record| predicate.all? { |k, v| record[k] == v } }
  end

  def build_nested_map(records, path, multi)
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

  def distinct_values(records, key, multi)
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
