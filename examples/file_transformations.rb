require 'filestack'

client = FilestackClient.new('APIKEY')
filelink = client.upload(filepath: 'test-files/calvinandhobbes.jpg')
transform = filelink.transform.resize(width: 100, height:100)
puts transform.url