# Security

EventStoreDB has a few options for security which are now all enabled by
default in EventStoreDB 20+:

- connections over TLS (SSL/HTTPS)
- username+password basic-auth credentials
- access control lists (ACLs) on streams or globally to an EventStoreDB

By default in EventStoreDB 20+, these are all enabled. The EventStoreDB
may be run with the `--insecure` command line flag to disable all of them
together.

## Setting up an EventStoreDB for security

The EventStore documentation now includes a helpful configuration wizard which
will help set up custom or cloud installations of EventStoreDB with the proper
networking, config, clustering, and certificates. For any production use-case,
see the EventStore documentation.

The repository for Spear includes a `certs/` directory with some generated
certificates. Note that the private keys are included in the repository, so the
certificates in that directory **are not suitable for any real-world case**.
Please only use them on a local machine not connected to the internet.

Assuming that you're running a Linux machine with the `eventstore-oss`
package installed, we can install the certificates in this repository like so.
Note that these commands will probably need to be run through `sudo`.

```console
$ cd /path/to/spear
$ mkdir -p /etc/eventstore/certs
$ cp -r ./certs/ca /etc/eventstore/certs/
$ cp ./certs/node1/* /etc/eventstore/certs
$ cp ./certs/eventstore.conf /etc/eventstore/
$ chown -R eventstore /etc/eventstore/
$ chgrp -R eventstore /etc/eventstore/
$ systemctl restart eventstore
```

Now the EventStoreDB should be set up to force TLS connections. You may
need to edit the existing service description to remove the `--insecure` flag
if present.

## Using custom TLS certificates with Spear

A `Spear.Connection` takes an `:opts` option which is passed to
`Mint.HTTP.connect/4`. We can inform mint of our custom `./certs/ca/ca.crt`
CA certificate like so:

```elixir
connection_config = [
  connection_string: "esdb://localhost:2113?tls=true",
  opts: [
    transport_opts: [
      cacertfile: Path.join([__DIR__ | ~w(certs ca ca.crt)])
    ]
  ]
]

# as a supervisor spec:
{Spear.Connection, connection_config}

# or as a direct call of start_link
iex> {:ok, conn} = Spear.Connection.start_link(connection_config)
```

Note that this same configuration works with a `Spear.Client` with this
configuration in application-config (`config/*.exs`).

If you're following along with the guide and have set up an EventStoreDB with
the certificates from the `certs/` directory in the spear repository, you
should now be able to spawn a connection which will force a TLS connection.

## Using TLS certificates signed by a public CA

Certificates signed by a public certificate authority (CA) such as the Domain
Validation (DV) certificates produced by the wonderful Letsencrypt project
should work out-of-the-box if the [`castore`](https://hex.pm/packages/castore)
dependency is included in your project.

```elixir
# mix.exs
  ..
  def deps do
    [
      {:spear, "~> 0.1"},
      {:castore, ">= 0.0.0"}
    ]
  end
  ..
```

With `castore`, you should not need to pass any `transport_opts` to Mint.

```elixir
connection_config = [
  connection_string: "esdb://localhost:2113?tls=true"
]
```

## Credentials

Now that TLS is enabled, we can safely pass basic-auth credentials over the
network. `Spear.Connection` accepts a `:credentials` option as a two-tuple
of `{username, password}`. E.g. with the default login credentials, a
connection can be configured like so:

```elixir
connection_config = [
  connection_string: "esdb://localhost:2113?tls=true",
  credentials: {"admin", "changeit"},
  opts: [
    transport_opts: [
      cacertfile: Path.join([__DIR__ | ~w(certs ca ca.crt)])
    ]
  ]
]
```

Credentials can also be passed on a per-request basis for all core Spear
functions (except `Spear.ping/2`; pings do not require/allow authentication
as they are not actual requests). All core functions allow a `:credentials`
option two-tuple of `{username, password}` which override the connection-level
credentials if provided.

E.g. reading a stream as a user named "Aladdin" (assuming such a user exists):

```elixir
# say we use `connection_config` from above: the connection has credentials
# of {"admin", "changeit"}
iex> {:ok, conn} = Spear.Connection.start_link(connection_config)
# the :credentials option overrides the connection-level credentials
iex> Spear.stream!(conn, "my_stream", credentials: {"Aladdin", "open sesame"}) |> Enum.take(1)
[%Spear.Event{}]
```

## Access control lists

Now that we know how to operate the client as a user, how does EventStoreDB
use credentials to allow or deny access to resources?

EventStoreDB uses access control lists (ACLs) to allow or deny access to
various operations per user or group.

ACLs (like virtually everything in EventStoreDB) are just events in a stream.
A simple ACL event body might look like

```json
{
  "$acl": {
    "$w": "$admins",
    "$r": "$all",
    "$d": "$admins",
    "$mw": "$admins",
    "$mr": "$admins"
  }
}
```

What do each of these mean?

| value | resource |
|------|---------|
| `$w` | write events to this stream |
| `$r` | read events from this stream |
| `$d` | delete this stream |
| `$mw` | write metadata associated with this stream |
| `$mr` | read metadata associated with this stream |
| `$admins` | the group of admin users |
| `$all` | all users (including anonymous users) |

Note that the ACL is controlled by writing stream metadata, so the `$mw`
permission allows a user to change the ACL of a stream.

### The global ACL

The `$streams` system stream may be used to change the default ACL applied to
all streams. By default, the global ACL is

```json
{
  "$userStreamAcl": {
    "$r": "$all",
    "$w": "$all",
    "$d": "$all",
    "$mr": "$all",
    "$mw": "$all"
  },
  "$systemStreamAcl": {
    "$r": "$admins",
    "$w": "$admins",
    "$d": "$admins",
    "$mr": "$admins",
    "$mw": "$admins"
  }
}
```

Where `$systemStreamAcl` applies to projected and otherwise system-created
streams and `$userStreamAcl` applies to all other (user-created) streams.

**This default is quite permissive**: any user including clients that do not
supply any credentials can read and write events to user-streams with the
default ACL.

The global ACL can be changed by writing an event of type `update-default-acl`
with a content type of `application/vnd.eventstore.events+json` with the above
body to the `$streams` system stream.

Spear provides the `Spear.Acl` struct and `Spear.set_global_acl/TODO` function
to set this without dealing with the nitty-gritty details of the structure
of that event.
