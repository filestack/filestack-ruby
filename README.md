[![Travis CI][travis_ci_badge]][travis_ci]
[![Coveralls][coveralls_badge]][coveralls]
[![Code Climate][code_climate_badge]][code_climate]

# Filestack Ruby SDK
<a href="https://www.filestack.com"><img src="https://filestack.com/themes/filestack/assets/images/press-articles/color.svg" align="left" hspace="10" vspace="6"></a>
This is the official Ruby SDK for Filestack - API and content management system that makes it easy to add powerful file uploading and transformation capabilities to any web or mobile application.

## Resources

* [Filestack](https://www.filestack.com)
* [Documentation](https://www.filestack.com/docs/sdks?ruby)
* [API Reference](https://filestack.github.io/filestack-ruby)

## Installing

Add this line to your application's Gemfile:

```ruby
gem 'filestack'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install filestack

## Usage

## IMPORTANT

A recent change (2.1.0) has renamed the Client to FilestackClient, and the Filelink to FilestackFilelink. Please make neccessary changes before upgrading to newest release if you run 2.0.1 or 2.0.0. This was to address namespace concerns by users with models and attributes named Client, and to be more consistent. 

```ruby
require 'filestack'
```
Intialize the client using your API key, and security if you are using it. 
```ruby
client = FilestackClient.new('YOUR_API_KEY', security: security_object)
```
### Uploading
Filestack uses multipart uploading by default, which is faster for larger files. This can be turned off by passing in ```multipart: false```. Multipart is disabled when uploading external URLs. 
```ruby
filelink = client.upload(filepath: '/path/to/file')

# OR

filelink = client.upload(external_url: 'http://someurl.com')
```

### Security
If security is enabled on your account, or if you are using certain actions that require security (delete, overwrite and certain transformations), you will need to create a security object and pass it into the client on instantiation. 

```ruby
security = FilestackSecurity.new('YOUR_APP_SECRET', options: {call: %w[read store pick]})
client = FilestackClient.new('YOUR_API_KEY', security: security)
```

### Using FilestackFilelinks
FilestackFilelink objects are representation of a file handle. You can download, get raw file content, delete and overwrite file handles directly. Security is required for overwrite and delete methods. 

### Transformations 
Transforms can be initiated one of two ways. The first, by calling ```transform``` on a filelink:

```ruby
transform = filelink.transform
```

Or by using an external URL via the client:

```ruby
transform = client.convert_external('https://someurl.com')
```

Transformations can be chained together as you please.

```ruby
transform = filelink.transform.resize(width: 100, height: 100).flip.enhance
```

You can retrieve the URL of a transform object:

```ruby
transform.url
```

Or you can store (upload) the transformation as a new filelink:

```ruby
new_filelink = transform.store
```

For a list of valid transformations, please see [here](https://www.filestack.com/docs/image-transformations).

### Tagging

If you have auto-tagging enabled onto your account, it can be called on any filelink object (tags don't work on external URLs).

```ruby
tags = filelink.tags
```

This will return a hash with labels and their associated confidence:

```ruby 
{
    "auto" => {
        "art"=>73,
        "big cats"=>79,
        "carnivoran"=>80,
        "cartoon"=>93,
        "cat like mammal"=>92,
        "fauna"=>86, "mammal"=>92, 
        "small to medium sized cats"=>89, 
        "tiger"=>92,
        "vertebrate"=>90},
    "user" => nil
}
```

SFW is called the same way, but returns a boolean value (true == safe-for-work, false == not-safe-for-work). 

```ruby
sfw = filelink.sfw
``` 

## Versioning

Filestack Ruby SDK follows the [Semantic Versioning](http://semver.org/).

## Issues

If you have problems, please create a [Github Issue](https://github.com/filestack/filestack-ruby/issues).

## Contributing

Please see [CONTRIBUTING.md](https://github.com/filestack/filestack-ruby/CONTRIBUTING.md) for details.

## Credits

Thank you to all the [contributors](https://github.com/filestack/filestack-ruby/graphs/contributors).

[travis_ci]: http://travis-ci.org/filestack/filestack-ruby

[travis_ci_badge]: https://travis-ci.org/filestack/filestack-ruby.svg?branch=master		
[code_climate]: https://codeclimate.com/github/filestack/filestack-ruby		
[code_climate_badge]: https://codeclimate.com/github/filestack/filestack-ruby.png		
[coveralls]: https://coveralls.io/github/filestack/filestack-ruby?branch=master		
[coveralls_badge]: https://coveralls.io/repos/github/filestack/filestack-ruby/badge.svg?branch=master
