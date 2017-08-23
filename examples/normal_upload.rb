require 'filestack'

client = FilestackClient.new('APIKEY')
filelink = client.upload(filepath: 'test-files/doom.mp4')
puts filelink.url