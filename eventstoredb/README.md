# EventStoreDB config

This directory contains EventStoreDB configuration used for testing.
Certificates can be created using the [es-gencert-cli] tool from EventStore.
The certs have a 365 day expiration period so this will need to be done yearly.

You can check the data in a certificate with `openssl`:

```
openssl x509 -in eventstoredb/certs/ca/ca.crt -text
```

This will tell you the valid date range.

[es-gencert-cli]: https://github.com/EventStore/es-gencert-cli
