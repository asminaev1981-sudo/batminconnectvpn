# Certificate analysis

Server certificate supplied for 94.141.98.124:

- Subject/CN: `94.141.98.124`
- Issuer: self-signed, `94.141.98.124`
- Validity: 2026-07-25 through 2036-07-22
- SHA-256: `89:77:D6:15:BB:A7:58:81:77:88:31:77:07:8F:28:89:2C:18:E7:B4:FC:34:51:46:21:5F:39:C4:A5:F2:93:ED`
- Subject Alternative Name: `94.141.104.252`

The SAN does not match the current server address `94.141.98.124`. Therefore the current test profile uses `insecure: true`. Before a public release, replace the certificate with one whose SAN contains the current IP or a stable domain, then disable insecure TLS verification.
