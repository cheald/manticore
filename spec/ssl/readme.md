test_truststore is a trust store which has trusted the cacert.pem certificate

localhost.pem is a server certificate signed by our test CA

We can test custom trust stores by:

1. Starting a server which uses localhost.pem/localhost.key to serve SSL
2. Trusting ca_cert.pem (via the test_truststore)

And then verifying that SSL operations complete successfully.

The test_truststore password is `test123`

You should never use these certificates or keys for anything other than testing Manticore's SSL behavior.