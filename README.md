# ecdsa_chain_pki
Scripts to create pki string for ecdsa algorithm.

#Chain hierarchy

CA
+ CA_INTERMEDIATE
  + user1
  + user2
  + ...

#Creating CA and CA_INTERMEDIATE keys and certificates

How to use:
./create_roots.sh <curve_size>

Example:
./create_roots.sh 384

This will create a nistp384 certificate chain with a CA certificate and a CA-INTERMEDIATE certificate. The CA-INTERMEDIATE will be used to sign certificate request for users.

#Creating user key and certificate

How to use:
./create_user.sh <curve_size> <user> <nick>

Example:
./create_roots.sh 384 'saulo.alessandre' 'Saulo Alessandre'

This will create a nistp384 user certificate signed by CA-INTERMEDIATE certificate. 
