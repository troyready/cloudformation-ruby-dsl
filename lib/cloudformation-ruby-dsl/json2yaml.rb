#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'json'

source = ARGV[0]
destination = ARGV[1]

obj = JSON.load(File.open(source))

fp = File.open(destination,'w')
YAML::dump(obj,fp)
fp.close

