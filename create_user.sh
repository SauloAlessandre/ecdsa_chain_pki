#!/bin/bash

# this script generates a user key for ECDSA algorithm
# and then create a certificate signed by INTERMEDIATE certificate.

# change this params
unit="mywork"
DIGEST=sha512
VALID=3650
OrganizationalUnit="/C=BR/ST=DF/L=Brasilia/O=TSE/OU=STI/OU=CSELE/OU=${unit^^}"
OrganizationalServer="tse.jus.br"

if [ "x$1" == "x-h" ]; then
    printf "use: $0 [curve] [user] [nick]\n"
    printf "\tex: $0 256 saulo.alessandre 'Saulo Alessandre'\n"
    exit 0
fi

#----------------------------------------------------- functions
ECHO_RED="\033[0;31m"
ECHO_BOLD="\033[1m"
ECHO_BLUE="\E[35m\033[1m"
ECHO_END="\033[0m"
function shmsg() {
    printf "+ - - - - - - - - - $@\n"
}

#-----------------------------------------------------
if [ "x$1" == "x" ]; then
    CURVE=256
else 
    CURVE=$1
fi

CURVEDIR=ca-${CURVE}
INTERDIR=ca_inter
echo -e "${ECHO_RED}=================== Enter ${CURVEDIR}/ ===================${ECHO_END}"
cd ${CURVEDIR}

CURVE_NAME=secp${CURVE}r1

#definindo os nomes
CA_CER=certs/ca-${unit}-${CURVE}.x509
INTER_KEY=${INTERDIR}/private/ca-intermediate-${unit}-${CURVE}.key.pem
INTER_CER=${INTERDIR}/certs/ca-intermediate-${unit}-${CURVE}.x509

cat ../openssl.cnf.tmpl | sed -e "s|PROJECT_DIR|${PWD}/${INTERDIR}|" -e "s|POLICY_TYPE|policy_loose|g" > openssl-u.cnf
mkdir -p ~/.${unit}/ecdsa/

#-----------------------------------------------------
if [ "x${2}" == "x" ]; then
    USER_EMAIL=${USER}
else
    USER_EMAIL=${2}
fi
if [ "x${3}" == "x" ]; then
    USER_NICK=${USER}
else
    USER_NICK=${3}
fi
USER_KEY=~/.${unit}/ecdsa/${USER_EMAIL}-${CURVE}.at.${unit}.key.pem
USER_CSR=${INTERDIR}/csr/${USER_EMAIL}-${CURVE}.at.${unit}.csr
USER_CER=${INTERDIR}/certs/${USER_EMAIL}-${CURVE}.at.${unit}.x509

#creating ECDSA key
shmsg "Creating secret key for ${ECHO_BLUE}${USER_KEY}${ECHO_END} email ${USER_EMAIL}@${OrganizationalServer}."
shmsg "Enter the new pass."
openssl ecparam -genkey -name ${CURVE_NAME} | openssl ec -aes256 -out ${USER_KEY}

#creating x509 CSR
shmsg "Creating X509 CSR for ${USER_CSR}"
shmsg "Enter the user key pass for ${ECHO_BLUE}${USER_KEY}${ECHO_END}"
openssl req -${DIGEST} -key ${USER_KEY} -config openssl-u.cnf -new \
    -out ${USER_CSR} -subj "${OrganizationalUnit}/CN=${USER_NICK}/emailAddress=${USER_EMAIL}@${OrganizationalServer}"
read -n 1 -p "Show X509 CSR [${USER_CSR}] (Y/n)? " opt
if [ "x-${opt}" == "x-" ] || [ "x-${opt,}" == "x-y" ]; then
    openssl req -text -noout -in ${USER_CSR}
else
    echo "ok"
fi
shmsg "Creating X509 certificate ${USER_CER}"
while [ true ]; do
    shmsg "Enter the intermediate key for ${ECHO_BLUE}${INTER_KEY}${ECHO_END}"
    openssl ca -config openssl-u.cnf -extensions usr_cert -keyfile ${INTER_KEY} -cert ${INTER_CER} -days ${VALID} \
        -notext -md ${DIGEST} -in ${USER_CSR} -out ${USER_CER}
    if [ $? -eq 0 ]; then
        break;
    fi
done
read -n 1 -p "Show X509 certificate [${USER_CER}] (Y/n)? " opt
if [ "x-${opt}" == "x-" ] || [ "x-${opt,}" == "x-y" ]; then
    openssl x509 -text -noout -in ${USER_CER}
else
    echo "ok"
fi

CA_DESENV=../${unit}-${CURVE}.x509
cat ${CA_CER} ${INTER_CER} ${INTERDIR}/certs/*.at.${unit}.x509 > ${CA_DESENV} 

rm openssl-u.cnf

cd ..

shmsg "${ECHO_BLUE}I M P O R T A N T!${ECHO_END}"
shmsg "1 - your secret key ${USER_KEY} was generated on ~/.${unit}/ecdsa"
shmsg "2 - copy certificate chain ${CA_DESENV##*/} to the linux/certs"

