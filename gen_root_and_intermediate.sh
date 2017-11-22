#!/usr/bin/env bash
# https://jamielinux.com/docs/openssl-certificate-authority/index.html

echo "This script is based on 'https://jamielinux.com/docs/openssl-certificate-authority/index.html'"

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
read -p "Press enter to continue"

pushd ~
my_cur_dir=`$PWD`

export BASE_CERT_DIR="$PWD"/certs
echo "Choose a directory to store all keys and certificates."
echo "Certificates and other info will be placed in directory '${BASE_CERT_DIR}'."
read -p "Press enter to continue"

echo "!!!  ALERT   !!!  ALERT   !!!  ALERT   !!!  ALERT   !!!  ALERT   !!!"
echo " The contents of '${BASE_CERT_DIR}' will be DELETED!"
read -p "Press enter to continue, or CTRL-C to abort."

rm -rf ${BASE_CERT_DIR}
if [ $? -ne 0 ] ; then
    echo "Unable to delete ${BASE_CERT_DIR}"
    exit 1
fi

echo \
"Create the directory structure. The index.txt and serial files act as a flat file database to keep track \
of signed certificates."
mkdir -p $BASE_CERT_DIR
if [ $? -ne 0 ] ; then
    echo "Unable to create ${BASE_CERT_DIR}"
    exit 1
fi

mkdir -p ${BASE_CERT_DIR}/ca
if [ $? -ne 0 ] ; then
    echo "Unable to create ${BASE_CERT_DIR}/ca"
    exit 1
fi
cd $BASE_CERT_DIR/ca
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca"
    exit 1
fi
mkdir certs crl newcerts private
if [ $? -ne 0 ] ; then
    echo "Unable to create directories {certs, crl, newcerts, private} in ${PWD}"
    exit 1
fi

chmod 700 private
if [ $? -ne 0 ] ; then
    echo "Unable to make the directory 'private' in ${PWD} owner read/write/execute (chmod 700)"
    exit 1
fi
touch index.txt
if [ $? -ne 0 ] ; then
    echo "Unable to create index.txt in ${PWD}"
    exit 1
fi
echo 1000 > serial
if [ $? -ne 0 ] ; then
    echo "Unable to create 'serial' file in ${PWD}"
    exit 1
fi

echo "You must create a configuration file for OpenSSL to use."
cp ${my_cur_dir}/root_ca_openssl.cnf $BASE_CERT_DIR/ca/openssl.cnf
if [ $? -ne 0 ] ; then
    echo "Unable to copy 'root_ca_openssl.cnf' file in ${my_cur_dir} to ${BASE_CERT_DIR}/ca/openssl.cnf"
    exit 1
fi
cd ${BASE_CERT_DIR}/ca
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca"
    exit 1
fi
read -p "Press enter to continue"

echo "Create the root key"
openssl genrsa -aes256 -out private/ca.key.pem 4096
if [ $? -ne 0 ] ; then
    echo "Unable to generate the private key in ${PWD}/ca/private/ca.key.pem"
    exit 1
fi

chmod 400 private/ca.key.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the private key in ${PWD}/ca/private/ca.key.pem owner read only (chmod 400)"
    exit 1
fi
read -p "Press enter to continue"

echo "Create the root certificate"
# Whenever you use the req tool, you must specify a configuration
# file to use with the -config option, otherwise OpenSSL will
# default to /etc/pki/tls/openssl.cnf.
cd ${BASE_CERT_DIR}/ca
openssl req -config openssl.cnf \
      -key private/ca.key.pem \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out certs/ca.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to generate the root CA certificate."
    exit 1
fi
chmod 444 certs/ca.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the CA certificate in ${PWD}/certs/ca.cert.pem 'all' read only (chmod 444)"
    exit 1
fi
read -p "Press enter to continue"

echo "Verify the root certificate"
openssl x509 -noout -text -in certs/ca.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to verify the CA certificate in ${PWD}/certs/ca.cert.pem"
    exit 1
fi

echo "Create the intermediate pair"

echo \
"An intermediate certificate authority (CA) is an entity that can sign certificates on behalf of the root CA. \
The root CA signs the intermediate certificate, forming a chain of trust."
echo \
"The purpose of using an intermediate CA is primarily for security. The root key can be kept offline and used \
as infrequently as possible. If the intermediate key is compromised, the root CA can revoke the intermediate \
certificate and create a new intermediate cryptographic pair."
read -p "Press enter to continue"

echo "Prepare the directory"
echo "Intermediate certificates and other info will be placed in directory '${BASE_CERT_DIR}/ca/intermediate'."
read -p "Press enter to continue"
mkdir -p ${BASE_CERT_DIR}/ca/intermediate
if [ $? -ne 0 ] ; then
    echo "Unable to create ${BASE_CERT_DIR}/ca/intermediate"
    exit 1
fi

cd ${BASE_CERT_DIR}/ca/intermediate
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca/intermediate"
    exit 1
fi
mkdir certs crl csr newcerts private
if [ $? -ne 0 ] ; then
    echo "Unable to create directories {certs, crl, newcerts, private} in ${PWD}"
    exit 1
fi
chmod 700 private
if [ $? -ne 0 ] ; then
    echo "Unable to make the directory 'private' in ${PWD} owner read/write/execute (chmod 700)"
    exit 1
fi

touch index.txt
if [ $? -ne 0 ] ; then
    echo "Unable to create index.txt in ${PWD}"
    exit 1
fi
echo 1000 > serial
if [ $? -ne 0 ] ; then
    echo "Unable to create 'serial' file in ${PWD}"
    exit 1
fi
echo 1000 > ${BASE_CERT_DIR}/ca/intermediate/crlnumber
if [ $? -ne 0 ] ; then
    echo "Unable to create 'crlnumber' file in ${BASE_CERT_DIR}/ca/intermediate"
    exit 1
fi

echo "You must create a configuration file for OpenSSL to use."
cp ${my_cur_dir}/intermediate_ca_openssl.cnf ${BASE_CERT_DIR}/ca/intermediate/openssl.cnf
if [ $? -ne 0 ] ; then
    echo "Unable to copy 'intermediate_ca_openssl.cnf' file in ${my_cur_dir} to ${BASE_CERT_DIR}/ca/intermediate/openssl.cnf"
    exit 1
fi

cd ${BASE_CERT_DIR}/ca
if [ $? -ne 0 ] ; then
    echo "Unable to change dir to ${BASE_CERT_DIR}/ca"
    exit 1
fi
read -p "Press enter to continue"

echo "Create the intermediate key"
openssl genrsa -aes256 \
      -out intermediate/private/intermediate.key.pem 4096
if [ $? -ne 0 ] ; then
    echo "Unable to generate the private key in ${PWD}intermediate/private/intermediate.key.pem"
    exit 1
fi

chmod 400 intermediate/private/intermediate.key.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the private key in ${PWD}/intermediate/private/intermediate.key.pem owner read only (chmod 400)"
    exit 1
fi
read -p "Press enter to continue"

echo "Create the intermediate certificate"
cd $BASE_CERT_DIR/ca
openssl req -config intermediate/openssl.cnf -new -sha256 \
      -key intermediate/private/intermediate.key.pem \
      -out intermediate/csr/intermediate.csr.pem
if [ $? -ne 0 ] ; then
    exit 1
fi

cd $BASE_CERT_DIR/ca
openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in intermediate/csr/intermediate.csr.pem \
      -out intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to generate the intermediate CA certificate."
    exit 1
fi

chmod 444 intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the CA certificate in ${PWD}/intermediate/certs/intermediate.cert.pem 'all' read only (chmod 444)"
    exit 1
fi
read -p "Press enter to continue"

echo "Verify the intermediate certificate"
openssl x509 -noout -text \
      -in intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to verify the CA certificate in ${PWD}/intermediate/certs/intermediate.cert.pem"
    exit 1
fi

echo "Verify the intermediate certificate against the root certificate. An OK indicates that the chain of trust is intact."
openssl verify -CAfile certs/ca.cert.pem \
      intermediate/certs/intermediate.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to verify the intermediate certificate against the root certificate"
    exit 1
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
    exit 1
fi

chmod 444 intermediate/certs/ca-chain.cert.pem
if [ $? -ne 0 ] ; then
    echo "Unable to make the CA certificate chain in ${PWD}/intermediate/certs/ca-chain.cert.pem 'all' read only (chmod 444)"
    exit 1
fi

echo \
"The CA and intermediate should be ready to use now.  Find them in ${BASE_CERT_DIR}"
popd
