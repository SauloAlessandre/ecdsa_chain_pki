#!/bin/bash

unit="sevin"
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

CURVEDIR=ca-${CURVE}
INTERDIR=ca_inter
echo -e "${ECHO_RED}=================== Creating ${CURVEDIR}/ ===================${ECHO_END}"
mkdir -p ${CURVEDIR}
cd ${CURVEDIR}

mkdir -p certs crl csr newcerts private
mkdir -p ${INTERDIR}/certs ${INTERDIR}/crl ${INTERDIR}/csr ${INTERDIR}/newcerts ${INTERDIR}/private
touch index.txt ${INTERDIR}/index.txt
echo 1000 > serial; echo 2219752222 > ${INTERDIR}/serial; 

CURVE_NAME=secp${CURVE}r1
DIGEST=sha512
VALID=3650
OrganizationalUnit="/C=BR/ST=DF/L=Brasilia/O=TSE/OU=STI/OU=CSELE/OU=SEVIN"
CA_KEY=private/ca-${unit}-${CURVE}.key.pem
CA_CER=certs/ca-${unit}-${CURVE}.x509

#especificando o arquivo de configuração do openssl
cat ../openssl.cnf.tmpl | sed -e "s|PROJECT_DIR|$PWD|" -e "s|POLICY_TYPE|policy_strict|g" > openssl.cnf

#criando uma chave ecdsa 256 cifrada
shmsg "Criando chave secreta ${ECHO_BOLD}${CA_KEY}${ECHO_END} para ROOT-CA"
while [ true ]; do
    shmsg "Informe uma senha nova."
    openssl ecparam -genkey -name ${CURVE_NAME} | openssl ec -aes256 -out ${CA_KEY}
    error=$?
    if [ $error -ne 0 ]; then
        shmsg "OCORREU UM ERRO ${error}"
        read -n1 -p "Tentar novamente?"
        continue
    fi
    break
done

shmsg "Criando certificado X509 ${CA_CER}"
shmsg "informe a senha ROOT-CA da chave ${ECHO_BOLD}${CA_KEY}${ECHO_END}."
#criando o certificado da SEVIN CA
openssl req -config openssl.cnf -extensions v3_ca -new -key ${CA_KEY} -${DIGEST} -x509 -days ${VALID} \
    -out ${CA_CER} -subj "${OrganizationalUnit}/CN=SEVIN-CA2019-${CURVE}/emailAddress=sevin@tse.jus.br"
read -n 1 -p "Exibir CER X509 [${CA_CER}] (Y/n)? " opt; opt=`echo $opt | tr [:upper:] [:lower:]`
if [ "x-${opt}" == "x-" ] || [ "x-${opt}" == "x-y" ]; then
    openssl x509 -text -noout -in ${CA_CER}
else
    echo "ok"
fi

#definindo os nomes
UNIT_KEY=${INTERDIR}/private/ca-intermediate-${unit}-${CURVE}.key.pem
UNIT_CSR=${INTERDIR}/csr/ca-intermediate-${unit}-${CURVE}.csr
UNIT_CER=${INTERDIR}/certs/ca-intermediate-${unit}-${CURVE}.x509

cat ../openssl.cnf.tmpl | sed -e "s|PROJECT_DIR|${PWD}/${INTERDIR}|" -e "s|POLICY_TYPE|policy_loose|g" > openssl-i.cnf

#-----------------------------------------------------
#criando a chave ECDSA
shmsg "Criando chave secreta para CA-INTER."
shmsg "informe uma senha nova para ${ECHO_BLUE}${UNIT_KEY}${ECHO_END}."
openssl ecparam -genkey -name ${CURVE_NAME} | openssl ec -aes256 -out ${UNIT_KEY}
#criando o CSR intermediária
shmsg "Criando requisição de certificado X509 ${UNIT_CSR}"
shmsg "informe a senha de CA-INTER ${ECHO_BLUE}${UNIT_KEY}${ECHO_END}"
openssl req -new -${DIGEST} -key ${UNIT_KEY} -out ${UNIT_CSR} \
    -subj "${OrganizationalUnit}/CN=SEVIN-CA2019 Intermediate-${CURVE}/emailAddress=sevin@tse.jus.br"
#verificando o CSR
read -n 1 -p "Exibir CSR x509 [${UNIT_CSR}] (Y/n)? " opt; opt=`echo $opt | tr [:upper:] [:lower:]`
if [ "x-${opt}" == "x-" ] || [ "x-${opt}" == "x-y" ]; then
    openssl req -text -noout -in ${UNIT_CSR}
else
    echo "ok"
fi

#criando o certificado intermediário
shmsg "Criando certificado X509 ${UNIT_CER}"
shmsg "informe a senha de ROOT-CA ${ECHO_BLUE}${CA_KEY}${ECHO_END}"
openssl ca -config openssl-i.cnf -extensions v3_intermediate_ca -keyfile ${CA_KEY} \
    -cert ${CA_CER} -days ${VALID} -notext -md ${DIGEST} -in ${UNIT_CSR} -out ${UNIT_CER}
read -n 1 -p "Exibir CER X509 [${UNIT_CER}] (Y/n)? " opt; opt=`echo $opt | tr [:upper:] [:lower:]`
if [ "x-${opt}" == "x-" ] || [ "x-${opt}" == "x-y" ]; then
    openssl x509 -text -noout -in ${UNIT_CER}
else
    echo "ok"
fi

cat ${CA_CER} ${UNIT_CER} > ../sevin-ca.x509
shmsg "${ECHO_BLUE}well done!${ECHO_END}"
shmsg "lembre-se de copiar a lista de certificados sevin-ca.x509"
shmsg "para o kernel linux/certs"

rm openssl.cnf openssl-i.cnf

cd ..

