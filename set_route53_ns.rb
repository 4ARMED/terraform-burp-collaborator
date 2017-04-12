#!/usr/bin/env ruby

require 'namecheap_api'
require 'json'

config = {
  sandbox: false,
  client_ip: ENV['NAMECHEAP_MYIP'],
  api_username: ENV['NAMECHEAP_API_USERNAME'],
  username: ENV['NAMECHEAP_USERNAME'],
  api_key: ENV['NAMECHEAP_API_KEY']
}

if ARGV.length < 1
  puts "[!] Usage: #{$0} <domain>"
  exit
end

zone = ARGV.shift.split(/\./)
name_servers = JSON.parse(`terraform output -json name_servers`)['value']
client = NamecheapApi::Client.new(config)
command_parameters = {
  :SLD => zone[0],
  :TLD => zone[1],
  :NameServers => name_servers.join(',')
}

puts "[*] You are about to update #{zone.join('.')} to use DNS servers #{name_servers.join(',')}"
print "[*] Are you sure you want to do this? (y/N): "
answer = STDIN.gets.chomp

unless answer =~ /^[yY]/
  puts "[!] Aborting update. Specify y next time if you want to run this update."
  exit
end

response = client.call('namecheap.domains.dns.setCustom', 'GET', command_parameters)
p response.results
