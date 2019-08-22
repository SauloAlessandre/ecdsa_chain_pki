# ecdsa_chain_pki
Scripts to create pki string for ecdsa algorithm.

How to use:
./create_roots.sh <curve_size>

Example:
./create_roots.sh 384

This will create a nistp384 certificate chain with a CA certificate and a CA-INTERMEDIATE certificate. The CA-INTERMEDIATE will be used to sign certificate request for users.

