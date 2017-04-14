#!/usr/bin/env ruby

=begin

#### Bonus for Namecheap customers

If you are using Namecheap as your registrar but AWS to host the zone then you can
use our handy Ruby script to update the NS records automatically via their API.
Bear in mind you will need API access to Namecheap which is not enabled by default.
Read the doc at https://www.namecheap.com/support/api/intro.aspx to tell you how to enable it.

Assuming you have done that, you will have an API username, a regular username (that you use on
the website, usually the same as the API one) and an API key. Use those values to set the following
environment variables on your local machine as follows.

```
export NAMECHEAP_MYIP=$(curl -s http://ip.4armed.com)
export NAMECHEAP_API_USERNAME="_your_namecheap_api_username_"
export NAMECHEAP_USERNAME="_your_namecheap_username_"
export NAMECHEAP_API_KEY="_your_namecheap_api_key_"
```

With these set, now you can run the nameserver update script for Namecheap:

```
$ ./set_route53_ns.rb 4armed.net
[*] You are about to update 4armed.net to use DNS servers ns-1276.awsdns-31.org,ns-1729.awsdns-24.co.uk,ns-212.awsdns-26.com,ns-828.awsdns-39.net
[*] Are you sure you want to do this? (y/N): y
[{:domain=>"4armed.net", :updated=>"true"}]

=end

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
