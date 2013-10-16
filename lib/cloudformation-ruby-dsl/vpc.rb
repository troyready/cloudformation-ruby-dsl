require "cloudformation-ruby-dsl/table"

module Vpc
  class << self
    attr_accessor :office_cidrs
    def office_cidrs()  Array(@office_cidrs);   end
  end


  def self.lookup(key, predicate)
    @@table.get(key, predicate)
  end

  def self.lookup_list(key, predicate)
    @@table.get_list(key, predicate)
  end

  def self.metadata_map(predicate, *keys)
    @@table.get_map(predicate, *keys)
  end

  def self.metadata_multimap(predicate, *keys)
    @@table.get_multimap(predicate, *keys)
  end

  def self.load_metadata_table(table_def = nil)
    table_def ||= 'region vpc vpc_id vpc_cidr vpc_visibility zone zone_suffix subnet_id subnet_cidr'
    @@table = Table.new table_def
  end

  load_metadata_table

end
