<p align="center"><img src="logo.svg" align="center" width="100"/></p>
<h1 align="center">Filestack Ruby SDK</h1>
<p align="center">
  <a href="https://travis-ci.org/filestack/filestack-ruby.svg?branch=master">
    <img src="https://img.shields.io/travis/filestack/filestack-ruby/master.svg?longCache=true&style=flat-square">
  </a>
  <a href="https://coveralls.io/github/filestack/filestack-ruby?branch=master">
    <img src="https://img.shields.io/coveralls/github/filestack/filestack-ruby/master.svg?longCache=true&style=flat-square">
  </a>
</p>
<p align="center">
Ruby SDK for Filestack API and content management system.
</p>

**Important: This is the readme for 2.1.0.**
A recent change (2.1.0) has renamed the `Client` to `FilestackClient`, and the `Filelink` to `FilestackFilelink`. Please make neccessary changes before upgrading to newest release if you run 2.0.1 or 2.0.0. This was to address namespace concerns by users with models and attributes named `Client`, and to be more consistent.

## Overview

* A multi-part uploader powered on the backend by the [Filestack CIN](https://www.filestack.com/products/content-ingestion-network).
* An interface to the [Filestack Processing Engine](https://www.filestack.com/docs/image-transformations) for transforming assets via URLs.
* The Filestack Picker - an upload widget for the web that integrates over a dozen cloud providers and provides pre-upload image editing.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'filestack'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install filestack

## Usage

### Import
```ruby
require 'filestack'
```
Intialize the client using your API key, and security if you are using it.

```ruby
client = FilestackClient.new('YOUR_API_KEY', security: security_object)
```
### Uploading
```ruby
filelink = client.upload(filepath: '/path/to/localfile')

# OR

filelink = client.upload(external_url: 'http://domain.com/image.png')


# Return response body on upload complete
puts filelink.upload_response

# Return uploaded filelink handle
puts filelink.handle
```

To upload a local, an IO object and an external file with following optional options:

```ruby
options = {
  filename: 'string',
  location: 'string',
  path: 'string',
  container: 'string',
  mimetype: 'string',
  region: 'string',
  workflows: ['workflow-id-1', 'workflow-id-2'],
  upload_tags: {
    key: 'value',
    key2: 'value'
  }
}

filelink = client.upload(filepath: '/path/to/localfile', options: { mimetype: 'image/png', filename: 'custom_filename.png' })

filelink = client.upload(external_url: 'http://domain.com/image.png', options: { mimetype: 'image/jpeg', filename: 'custom_filename.png' })
```

To store file on `dropbox`, `azure`, `gcs` or `rackspace`, you must have the chosen provider configured in the developer portal to enable this feature. By default the file is stored on `s3`. You can add more details of the storage in `options`.

```ruby
filelink = client.upload(filepath: '/path/to/file', storage: 's3', options: { path: 'folder_name/', container: 'container_name', location: 's3', region: 'region_name' })

filelink = client.upload(external_url: 'http://someurl.com/image.png', options: { location: 'dropbox', path: 'folder_name' })
```

### Workflows
Workflows allow you to wire up conditional logic and image processing to enforce business processes, automate ingest, and save valuable development time. In order to trigger the workflow job for each upload:

```ruby
filelink = client.upload(filepath: '/path/to/file', options: { workflows: ["workflow_id_1", "workflow_id_2"] })

#OR

filelink = client.upload(external_url: 'http://someurl.com/image.png', options: { workflows: ["workflow_id_1"] })

# Return workflows jobids on upload complete
puts filelink.upload_response["workflows"]
```

### Security
If security is enabled on your account, or if you are using certain actions that require security (delete, overwrite and certain transformations), you will need to create a security object and pass it into the client on instantiation.

```ruby
security = FilestackSecurity.new('YOUR_APP_SECRET', options: {call: %w[read store pick runWorkflow]})
client = FilestackClient.new('YOUR_API_KEY', security: security)
```

### Using FilestackFilelinks
FilestackFilelink objects are representation of a file handle. You can download, get raw file content, delete and overwrite file handles directly. Security is required for overwrite and delete methods.

Initialize the filelink using the file handle, your API key, and security if required. The file handle is the string following the last slash `/` in the file URL.

```ruby
filelink = FilestackFilelink.new(handle, apikey: 'YOUR_API_KEY', security: security_object)
```

### Deletion
You can delete a file by simply calling `delete` on the filelink.

```ruby
filelink.delete
```

### Transformations
Transforms can be initiated one of two ways. The first, by calling ```transform``` on a filelink:

```ruby
transform = filelink.transform
```

Or by using an external URL via the client:

```ruby
transform = client.transform_external('https://someurl.com')
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

### Fallback
Return `default` file if the source of the transformation does not work or the transformation fails.
To use fallback, you should provide `handle` of the file that should be returned. Optionally, you can add `cache`, which means number of seconds fallback response should be cached in CDN.

```ruby
transform = client.transform_external('https://someurl.com/file.png').fallback(file: 'DEFAULT_HANDLE_OR_FILEPATH')
```

If you are using fallback handle that belongs to different application than the one which runs transformation (APIKEY) and it is secured with security policy, appropriate signature and policy with read call should be used:

```ruby
transform = client.transform_external('https://someurl.com/file.png').fallback(file: 'DEFAULT_HANDLE_OR_FILEPATH?policy=HANDLE_APIKEY_POLICY&signature=HANDLE_APIKEY_SIGNATURE', cache: 10)
```

### Content
Sets `Content-Disposition` header for given file.

```ruby
transform = filelink.transform.content(filename: 'DEFAULT_FILENAME', type: 'TYPE')
```

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
