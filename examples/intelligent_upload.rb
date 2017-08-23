require 'filestack'

# intelligent upload flow requires you to pass in the intelligent parameter
# and have the service enabled on your application
client = FilestackClient.new('APIKEY')
filelink = client.upload(filepath: 'test-files/doom.mp4', intelligent: true)
puts filelink.url