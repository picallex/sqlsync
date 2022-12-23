# sqlsync

Sqlsync sincroniza la data SQL en una direccion.

Se usa para sincronizar desde el sqlite de freeswitch a la base de datos de postgres.

Ojo solo usar para:

* tablas que no manejen llaves foraneas con integridad referencial
* tablas que no manejen data duplicadas
* tablas que sean de muy pocos registros

## Installation

generar executable **bin/sqlsync**

~~~
$ make docker-shards-production
~~~

## Usage

~~~
$ sqlsync -c sqlsync.json
~~~

### Development

1. `make docker-test`
2. Repetir `paso 1`
~~~

### Configuration

ver **sqlsync.json** como ejemplo.

## Contributing

1. Fork it (<https://github.com/bit4bit/sqlsync/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jovany Leandro G.C](jovany@picallex.com) - creator and maintainer

## Alternatives

* http://silvercoders.com/en/products/sqlsync/
* https://github.com/rla/sql-sync
* https://github.com/bhmj/sqlsync
* https://github.com/vielhuber/syncdb
