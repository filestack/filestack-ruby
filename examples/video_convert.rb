require 'filestack'

client = FilestackClient.new('APIKEY')
filelink = client.upload(filepath: 'test-files/doom.mp4')
video = filelink.transform.av_convert(width: 100, height: 100)
while video.status != 'completed'
    puts video.status
end
filelink = video.to_filelink
puts filelink.url