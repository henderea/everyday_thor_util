#/usr/bin/env ruby

require 'io/console/size'

rows, cols = IO.console_size
require_relative 'lib/everyday_thor_util/block_extractor'

                    b1 = EverydayThorUtil::BlockExtractor.extract_block('block1', 4) { |var_name = 'hi', var_name2 = "{", options = {'tmp' => 'tmp2'}|
                      var_map = { 'hi' => 'bye', 'bye' => 'hi', 'jive' => 'why' }
                      vars = var_map.keys
                      vars = vars.grep(/.*#{var_name}.*/) if var_name
                      vars.sort!
                      if vars.nil? || vars.empty?
                        puts "Did not find any variables matching #{var_name}"
                      else
                        longest_var = vars.map { |v| v.to_s.length }.max
                        vars.each { |v| puts "#{v.to_s.ljust(longest_var)} => #{var_map[v].to_s}" }
                      end
                    }.join("\n")

puts b1
eval b1

puts
puts

puts "block1('i')"
block1('i')

puts
puts ('=' * cols)
puts

b2 = EverydayThorUtil::BlockExtractor.extract_block('block2') { puts 'hi' }.join("\n")
puts b2
eval b2

puts
puts

puts 'block2'
block2

puts
puts ('=' * cols)
puts

lm1 =->(hi = 1, bye = {}) {
  puts hi
  puts bye.inspect
}

l1 = EverydayThorUtil::BlockExtractor.extract_lambda('lambda1', lm1).join("\n")
puts l1
eval l1

puts
puts

puts 'lambda1(5, a: :b, b: :c, c: :d)'
lambda1(5, a: :b, b: :c, c: :d)

puts
puts ('=' * cols)
puts

lm2 =-> { puts 'bye!' }

l2 = EverydayThorUtil::BlockExtractor.extract_lambda('lambda2', lm2).join("\n")
puts l2
eval l2

puts
puts

puts 'lambda2'
lambda2