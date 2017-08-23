require 'filestack'

security = FilestackSecurity.new('APP_SECRET')
client = FilestackClient.new('APIKEY', security: security)
filelink = client.upload(filepath: 'test-files/doom.mp4')
puts filelink.url
