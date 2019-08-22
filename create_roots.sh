#!/bin/bash

# change this params
unit="mywork"
DIGEST=sha512
VALID=3650
OrganizationalUnit="/C=BR/ST=DF/L=Brasilia/O=TSE/OU=STI/OU=CSELE/OU=${unit^^}"
OrganizationalServer="tse.jus.br"

if [ "x$1" == "x-h" ]; then
    printf "use: $0 [curve_size]\n"
    printf "\tex: $0 256\n"
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

CURVE_NAME=secp${CURVE}r1
CURVEDIR=ca-${CURVE}
INTERDIR=ca_inter
YEAR=`date +"%Y"`
echo -e "${ECHO_RED}=================== Creating ${CURVEDIR}/ ===================${ECHO_END}"
mkdir -p ${CURVEDIR}
cd ${CURVEDIR}

mkdir -p certs crl csr newcerts private
mkdir -p ${INTERDIR}/certs ${INTERDIR}/crl ${INTERDIR}/csr ${INTERDIR}/newcerts ${INTERDIR}/private
touch index.txt ${INTERDIR}/index.txt
echo 1000 > serial; echo 2219752222 > ${INTERDIR}/serial; 

CA_KEY=private/ca-${unit}-${CURVE}.key.pem
CA_CER=certs/ca-${unit}-${CURVE}.x509

#create openssl config
cat ../openssl.cnf.tmpl | sed -e "s|PROJECT_DIR|$PWD|" -e "s|POLICY_TYPE|policy_strict|g" > openssl.cnf

#create ciphered ECDSA secret key
shmsg "Creating secret key for ROOT-CA ${ECHO_BLUE}${CA_KEY}${ECHO_END}."
while [ true ]; do
    shmsg "Enter the new pass."
    openssl ecparam -genkey -name ${CURVE_NAME} | openssl ec -aes256 -out ${CA_KEY}
    error=$?
    if [ $error -ne 0 ]; then
        shmsg "Something is wrong ${error}"
        read -n1 -p "Try again?"
        continue
    fi
    break
done

shmsg "Creating X509 certificate for ROOT-CA ${CA_CER}"
shmsg "Enter pass for ROOT-CA ${ECHO_BLUE}${CA_KEY}${ECHO_END}."
#create root certificate
openssl req -config openssl.cnf -extensions v3_ca -new -key ${CA_KEY} -${DIGEST} -x509 -days ${VALID} \
    -out ${CA_CER} -subj "${OrganizationalUnit}/CN=${unit^^}-CA${YEAR}-${CURVE}/emailAddress=${unit}@${OrganizationalServer}"
read -n 1 -p "Show X509 certificate [${CA_CER}] (Y/n)? " opt;
if [ "x-${opt}" == "x-" ] || [ "x-${opt,}" == "x-y" ]; then
    openssl x509 -text -noout -in ${CA_CER}
else
    echo "ok"
fi

#intermediate ca
UNIT_KEY=${INTERDIR}/private/ca-intermediate-${unit}-${CURVE}.key.pem
UNIT_CSR=${INTERDIR}/csr/ca-intermediate-${unit}-${CURVE}.csr
UNIT_CER=${INTERDIR}/certs/ca-intermediate-${unit}-${CURVE}.x509

cat ../openssl.cnf.tmpl | sed -e "s|PROJECT_DIR|${PWD}/${INTERDIR}|" -e "s|POLICY_TYPE|policy_loose|g" > openssl-i.cnf

#-----------------------------------------------------
#create ciphered ECDSA secret key
shmsg "Creating secret key for CA-INTER ${ECHO_BLUE}${UNIT_KEY}${ECHO_END}."
while [ true ]; do
    shmsg "Enter the new pass."
    openssl ecparam -genkey -name ${CURVE_NAME} | openssl ec -aes256 -out ${UNIT_KEY}
    error=$?
    if [ $error -ne 0 ]; then
        shmsg "Something is wrong ${error}"
        read -n1 -p "Try again?"
        continue
    fi
    break
done

#create intermediate CSR
shmsg "Creating X509 CSR ${UNIT_CSR}"
shmsg "Enter pass for CA-INTER ${ECHO_BLUE}${UNIT_KEY}${ECHO_END}"
openssl req -new -${DIGEST} -key ${UNIT_KEY} -out ${UNIT_CSR} \
    -subj "${OrganizationalUnit}/CN=${unit^^}-CA${YEAR} Intermediate-${CURVE}/emailAddress=${unit}@${OrganizationalServer}"
read -n 1 -p "Show x509 CSR [${UNIT_CSR}] (Y/n)? " opt; 
if [ "x-${opt}" == "x-" ] || [ "x-${opt,}" == "x-y" ]; then
    openssl req -text -noout -in ${UNIT_CSR}
else
    echo "ok"
fi

#criando o certificado intermediário
shmsg "Creating X509 intermediate certificate ${UNIT_CER}"
shmsg "Enter pass for ROOT-CA ${ECHO_BLUE}${CA_KEY}${ECHO_END}"
openssl ca -config openssl-i.cnf -extensions v3_intermediate_ca -keyfile ${CA_KEY} \
    -cert ${CA_CER} -days ${VALID} -notext -md ${DIGEST} -in ${UNIT_CSR} -out ${UNIT_CER}
read -n 1 -p "Show x509 CER [${UNIT_CER}] (Y/n)? " opt
if [ "x-${opt}" == "x-" ] || [ "x-${opt,}" == "x-y" ]; then
    openssl x509 -text -noout -in ${UNIT_CER}
else
    echo "ok"
fi

shmsg "${ECHO_BLUE}well done!${ECHO_END}"

rm openssl.cnf openssl-i.cnf

cd ..
