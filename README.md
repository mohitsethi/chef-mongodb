# MongoDB cookbook


## Description

Configures [Mongodb](http://mongodb.org) via Opscode Chef

It can handle multiple instances with different configuratioins and differend versions on the same machine.

Please note that this cookbook does not use the 10gen apt repository, and instead downloads the required binaries from a given server.

## Supported Platforms

* Ubuntu
* Debian

## Recipes

* `MongoDB` - The default no-op recipe.

## Providers
* `mongodb_db` - Configures mongodb instance

## Usage
###Provider parameters:

* `url`: url for mongodb binary tgz (default: https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.6.1.tgz)
* `home`: directory for mongodb instance (default "/opt")
* `bind_ip`: listen address (default "127.0.0.1")
* `port`: listen port (default 27017)
* `default_instance`: creates symlink (default false)
* `replSet`: replica set name (default not set)
* `smallfiles`: use smallfile allocation (default false)
* `journal`: use durable journaling (default true)
* `notablescan`: disables queries using fts (default true)

#### A mongodb instance with custom parameters:
```ruby
mongodb_db 'example' do
    port '27017'
    bind_ip '0.0.0.0'
    default_instance true
end
```

## TODO
Implement sharded cluster support.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Authors

* Mohit Sethi <mohit@sethis.in>
