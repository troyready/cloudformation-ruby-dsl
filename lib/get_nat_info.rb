#!/usr/bin/env ruby

require 'rubygems'
require 'aws-sdk'
require 'optparse'
require 'ostruct'
require 'pp'
require 'pry'

class Cmdline

  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name} [options] VPC REGION"
    end

    opts.parse!(args)
    return_hash = {:options => options }

    if args.empty?
      puts opts
      exit(-1)
    end

    if %w(dev qa prod).include?(args[0])
      return_hash[:vpc] = args[0]
    else
      puts "First arg must be a valid vpc name!"
      exit(-1)
    end

    if %w(us-east-1 us-west-2 eu-west-1).include?(args[1])
      return_hash[:region] = args[1]
    else
      puts "Second arg must be a valid region name!"
      exit(-1)
    end

    return_hash
  end

end


class AwsData

  attr_accessor :region, :vpc, :ec2

  def initialize(region = nil, vpc = nil)
    @region = region
    @vpc = vpc
    @ec2 = login(@region)
  end

  def login(region)
    ec2 = AWS::EC2.new()
  end

  def get_tagged_instances_network_int(tag_value)
    eips = []
    return nil if @ec2.instances.tagged_values(tag_value).entries.empty?
    @ec2.instances.tagged_values("*-nat*").each { |x|
      eips += x.network_interfaces.map { |y| y.elastic_ip }.compact
    }
    raise if eips.empty?
    eips.map { |eip| eip.ip_address }
  end

end


def main(args)

  ad = AwsData.new(args[:region], args[:vpc])

  ips = ad.get_tagged_instances_network_int('dev-nat*')
  ips.each { |ip| puts ip + '/32'}

end

if __FILE__ == $0

  args = Cmdline.parse(ARGV)
  main(args)

end
