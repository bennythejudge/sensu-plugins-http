#! /usr/bin/env ruby
#
#   check-https-cert
#
# DESCRIPTION:
#    Checks the expiration date of a URL SSL Certificate
#    and notifies if it is before the expiry parameter.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: nrt-https
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Rhommel Lamas <roml@rhommell.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'net/https'

#
# Check HTTP
#
class CheckHttpCert < Sensu::Plugin::Check::CLI
  option :url,
         short: '-u URL',
         long: '--url URL',
         proc: proc(&:to_s),
         description: 'A URL to connect to'

  option :warning,
         short: '-w',
         long: '--warning DAYS',
         proc: proc(&:to_i),
         description: 'Warn EXPIRE days before cert expires'

  option :critical,
         short: '-c',
         long: '--critical DAYS',
         proc: proc(&:to_i),
         description: 'Critical EXPIRE days before cert expires'

  option :insecure,
         short: '-k',
         boolean: true,
         description: 'Enabling insecure connections',
         default: false

  def run
    uri = URI.parse(config[:url])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    if config[:insecure]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    else
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end

    http.start do |h|
      @cert = h.peer_cert
    end
    days_until = ((@cert.not_after - Time.now) / (60 * 60 * 24)).to_i

    if days_until <= 0
      critical "Expired #{days_until.abs} days ago."
    elsif days_until < config[:critical].to_i
      critical "SSL expires on #{@cert.not_after} - #{days_until} days left."
    elsif days_until < config[:warning].to_i
      warning "SSL expires on #{@cert.not_after} - #{days_until} days left."
    else
      ok "SSL expires on #{@cert.not_after} - #{days_until} days left."
    end

  rescue
    critical "Could not connect to #{config[:url]}"
  end
end
