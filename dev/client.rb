#!/usr/bin/env ruby
# coding: utf-8
# cf. https://gist.github.com/sonots/7751554

require 'net/http'
require 'uri'

# unicorn spec/app.ru -p 4321
# unicorn spec/proxy.ru -p 4322
PORT = ARGV[0] || 8080

http = Net::HTTP.new "localhost", PORT
request = Net::HTTP::Get.new "/slow_stream"
#request['Transfer-Encoding'] = 'chunked'
request['Connection'] = 'keep-alive'
http.request(request){|response|
  puts "content-length: #{response.content_length}"
  body = []
  response.read_body{|x|
    body << Time.now
    puts "read_block: #{body.length}, #{x.size}byte(s)"
  }
  puts body
}
