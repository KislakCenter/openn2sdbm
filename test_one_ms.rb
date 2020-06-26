#!/usr/bin/env ruby

require_relative 'lib/tei_data'
require 'pp'

tei_file = ARGV.shift

data = extract_data open tei_file

pp data