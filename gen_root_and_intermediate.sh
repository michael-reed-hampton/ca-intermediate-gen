#!/usr/bin/env bash
# https://jamielinux.com/docs/openssl-certificate-authority/index.html

echo "This script is based on 'https://jamielinux.com/docs/openssl-certificate-authority/index.html'"

quiet="false"
while [ $# -ne 0 ]
do
    arg="$1"
    case "$arg" in
        -quiet)
            quiet="true"
            ;;
        *)
            nothing="true"
            ;;
    esac
    shift
done

echo \
"A certificate authority (CA) is an entity that signs digital certificates. Many websites need to \
let their customers know that the connection is secure, so they pay an internationally trusted CA \
(eg, VeriSign, DigiCert) to sign a certificate for their domain.\
"
echo \
"In some cases it may make more sense to act as your own CA, rather than paying a CA like DigiCert. \
Common cases include securing an intranet website, or for issuing certificates to clients to allow \
them to authenticate to a server (eg, Apache, OpenVPN).\
"
echo \
"Acting as a certificate authority (CA) means dealing with cryptographic pairs of private keys and \
public certificates. The very first cryptographic pair we’ll create is the root pair. This consists \
of the root key (ca.key.pem) and root certificate (ca.cert.pem). This pair forms the identity of your CA.\
"
echo \
"Typically, the root CA does not sign server or client certificates directly. The root CA is only ever \
used to create one or more intermediate CAs, which are trusted by the root CA to sign certificates on \
their behalf. This is best practice. It allows the root key to be kept offline and unused as much as \
possible, as any compromise of the root key is disastrous.\
"
# We want to do the 'popd' before exiting in all cases.
bail_out () {
  popd
  exit 1
}
press_a_key () {
  if [[ ${quiet} != "true" ]]; then
      read -p "Press enter to continue, or CTRL-C to abort."
  fi
}
press_a_key

# I want to set this up to be done by a script, so I have the values here.
countryName=US
stateOrProvinceName=Colorado
localityName=Denver
organizationName="Example Organization"
organizationalUnitName="Engineering Division"
emailAddress="example+certs@example.org"

BASE_SUBJ="/emailAddress=${emailAddress}/C=${countryName}/ST=${stateOrProvinceName}/L=${localityName}/O=${organizationName}/OU=${organizationalUnitName}"

ROOT_CA_PASS=rootcapass
ROOT_CA_SUBJ="${BASE_SUBJ}/CN=Clover CDS Root CA"

INTERMEDIATE_CA_PASS=intermediatecapass
INTERMEDIATE_CA_SUBJ="${BASE_SUBJ}/CN=Clover CDS Intermediate CA"

my_cur_dir="$PWD"
echo ${my_cur_dir}
pushd ~

export BASE_CERT_DIR="$PWD"/certs
echo "Choose a directory to store all keys and certificates."
echo "Certificates and other info will be placed in directory '${BASE_CERT_DIR}'."
press_a_key

echo "!!!  ALERT   !!!  ALERT   !!!  ALERT   !!!  ALERT   !!!  ALERT   !!!"
echo " The contents of '${BASE_CERT_DIR}' will be DELETED!"
press_a_key

rm -rf ${BASE_CERT_DIR}
if [ $? -ne 0 ] ; then
    echo "Unable to delete ${BASE_CERT_DIR}"
    bail_out
fi

echo \
"Create the directory structure. The index.txt and serial files act as a flat file database to keep track \
of signed certificates."
mkdir -p $BASE_CERT_DIR
if [ $? -ne 0 ] ; then
    echo "Unable to create ${BASE_CERT_DIR}"
    bail_out
fi

mkdir -p ${BASE_CERT_DIR}/ca
if [ $? -ne 0 ] ; then
    echo "Unable to create ${BASE_CERT_DIR}/ca"
    bail_out
fi
cd $BASE_CERT_DIR/ca
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca"
    bail_out
fi
mkdir certs crl newcerts private
if [ $? -ne 0 ] ; then
    echo "Unable to create directories {certs, crl, newcerts, private} in ${PWD}"
    bail_out
fi

chmod 700 private
if [ $? -ne 0 ] ; then
    echo "Unable to make the directory 'private' in ${PWD} owner read/write/execute (chmod 700)"
    bail_out
fi
touch index.txt
if [ $? -ne 0 ] ; then
    echo "Unable to create index.txt in ${PWD}"
    bail_out
fi
echo 1000 > serial
if [ $? -ne 0 ] ; then
    echo "Unable to create 'serial' file in ${PWD}"
    bail_out
fi

echo "You must create a configuration file for OpenSSL to use."
cp ${my_cur_dir}/root_ca_openssl.cnf $BASE_CERT_DIR/ca/openssl.cnf
if [ $? -ne 0 ] ; then
    echo "Unable to copy 'root_ca_openssl.cnf' file in ${my_cur_dir} to ${BASE_CERT_DIR}/ca/openssl.cnf"
    bail_out
fi
cd ${BASE_CERT_DIR}/ca
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca"
    bail_out
fi
press_a_key

echo "Create the root key"
openssl genrsa -aes256 -passout pass:${ROOT_CA_PASS} -out private/ca.key.pem 4096
if [ $? -ne 0 ] ; then
    echo "Unable to generate the private key in ${PWD}/ca/private/ca.key.pem"
    bail_out
fi

chmod 400 private/ca.key.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the private key in ${PWD}/ca/private/ca.key.pem owner read only (chmod 400)"
    bail_out
fi
press_a_key

echo "Create the root certificate"
# Whenever you use the req tool, you must specify a configuration
# file to use with the -config option, otherwise OpenSSL will
# default to /etc/pki/tls/openssl.cnf.
cd ${BASE_CERT_DIR}/ca
openssl req -config openssl.cnf \
      -key private/ca.key.pem \
      -passin pass:${ROOT_CA_PASS} \
      -subj "${ROOT_CA_SUBJ}" \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out certs/ca.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to generate the root CA certificate."
    bail_out
fi
chmod 444 certs/ca.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the CA certificate in ${PWD}/certs/ca.cert.pem 'all' read only (chmod 444)"
    bail_out
fi
press_a_key

echo "Verify the root certificate"
openssl x509 -noout -text -in certs/ca.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to verify the CA certificate in ${PWD}/certs/ca.cert.pem"
    bail_out
fi

echo "Create the intermediate pair"

echo \
"An intermediate certificate authority (CA) is an entity that can sign certificates on behalf of the root CA. \
The root CA signs the intermediate certificate, forming a chain of trust."
echo \
"The purpose of using an intermediate CA is primarily for security. The root key can be kept offline and used \
as infrequently as possible. If the intermediate key is compromised, the root CA can revoke the intermediate \
certificate and create a new intermediate cryptographic pair."
press_a_key

echo "Prepare the directory"
echo "Intermediate certificates and other info will be placed in directory '${BASE_CERT_DIR}/ca/intermediate'."
press_a_key
mkdir -p ${BASE_CERT_DIR}/ca/intermediate
if [ $? -ne 0 ] ; then
    echo "Unable to create ${BASE_CERT_DIR}/ca/intermediate"
    bail_out
fi

cd ${BASE_CERT_DIR}/ca/intermediate
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca/intermediate"
    bail_out
fi
mkdir certs crl csr newcerts private
if [ $? -ne 0 ] ; then
    echo "Unable to create directories {certs, crl, newcerts, private} in ${PWD}"
    bail_out
fi
chmod 700 private
if [ $? -ne 0 ] ; then
    echo "Unable to make the directory 'private' in ${PWD} owner read/write/execute (chmod 700)"
    bail_out
fi

touch index.txt
if [ $? -ne 0 ] ; then
    echo "Unable to create index.txt in ${PWD}"
    bail_out
fi
echo 1000 > serial
if [ $? -ne 0 ] ; then
    echo "Unable to create 'serial' file in ${PWD}"
    bail_out
fi
echo 1000 > ${BASE_CERT_DIR}/ca/intermediate/crlnumber
if [ $? -ne 0 ] ; then
    echo "Unable to create 'crlnumber' file in ${BASE_CERT_DIR}/ca/intermediate"
    bail_out
fi

echo "You must create a configuration file for OpenSSL to use."
cp ${my_cur_dir}/intermediate_ca_openssl.cnf ${BASE_CERT_DIR}/ca/intermediate/openssl.cnf
if [ $? -ne 0 ] ; then
    echo "Unable to copy 'intermediate_ca_openssl.cnf' file in ${my_cur_dir} to ${BASE_CERT_DIR}/ca/intermediate/openssl.cnf"
    bail_out
fi

cd ${BASE_CERT_DIR}/ca
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca"
    bail_out
fi
press_a_key

echo "Create the intermediate key"
openssl genrsa -aes256 \
      -passout pass:${INTERMEDIATE_CA_PASS} \
      -out intermediate/private/intermediate.key.pem 4096
if [ $? -ne 0 ] ; then
    echo "Unable to generate the private key in ${PWD}intermediate/private/intermediate.key.pem"
    bail_out
fi

chmod 400 intermediate/private/intermediate.key.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the private key in ${PWD}/intermediate/private/intermediate.key.pem owner read only (chmod 400)"
    bail_out
fi
press_a_key

echo "Create the intermediate certificate"
cd $BASE_CERT_DIR/ca
openssl req -config intermediate/openssl.cnf -new -sha256 \
      -key intermediate/private/intermediate.key.pem \
      -passin pass:${INTERMEDIATE_CA_PASS} \
      -subj "${INTERMEDIATE_CA_SUBJ}" \
      -out intermediate/csr/intermediate.csr.pem
if [ $? -ne 0 ] ; then
    bail_out
fi

echo "Sign the CSR for the intermediate CA"
cd $BASE_CERT_DIR/ca
# below, '-batch' avoids the prompt
openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -passin pass:${ROOT_CA_PASS} \
      -batch \
      -in intermediate/csr/intermediate.csr.pem \
      -out intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to generate the intermediate CA certificate."
    bail_out
fi

chmod 444 intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the CA certificate in ${PWD}/intermediate/certs/intermediate.cert.pem 'all' read only (chmod 444)"
    bail_out
fi
press_a_key

echo "Verify the intermediate certificate"
openssl x509 -noout -text \
      -in intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to verify the CA certificate in ${PWD}/intermediate/certs/intermediate.cert.pem"
    bail_out
fi

echo "Verify the intermediate certificate against the root certificate. An OK indicates that the chain of trust is intact."
openssl verify -CAfile certs/ca.cert.pem \
      intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to verify the intermediate certificate against the root certificate"
    bail_out
fi

echo "Create the certificate chain file"
echo \
"When an application (eg, a web browser) tries to verify a certificate signed by the intermediate CA, \
it must also verify the intermediate certificate against the root certificate. To complete the chain of \
trust, create a CA certificate chain to present to the application."
echo \
"To create the CA certificate chain, concatenate the intermediate and root certificates together. We will \
use this file later to verify certificates signed by the intermediate CA."
echo \
"!Note:"
echo \
"Our certificate chain file must include the root certificate because no client application knows about it \
yet. A better option, particularly if you’re administrating an intranet, is to install your root certificate \
on every client that needs to connect. In that case, the chain file need only contain your intermediate certificate."
cat intermediate/certs/intermediate.cert.pem \
      certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to concatenate the certificates!"
    bail_out
fi

chmod 444 intermediate/certs/ca-chain.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the CA certificate chain in ${PWD}/intermediate/certs/ca-chain.cert.pem 'all' read only (chmod 444)"
    bail_out
fi

echo \
"The CA and intermediate should be ready to use now.  Find them in ${BASE_CERT_DIR}"
popd
