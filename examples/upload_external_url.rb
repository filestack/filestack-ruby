require 'filestack'

# intelligent upload flow requires you to pass in the intelligent parameter
# and have the service enabled on your application
client = FilestackClient.new('APIKEY')
filelink = client.upload(external_url: 'http://trailers.divx.com/divx_prod/profiles/WiegelesHeliSki_DivXPlus_19Mbps.mkv')
puts filelink.url