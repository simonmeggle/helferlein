#!/bin/bash

if [ ! -d "$1" ]; then 
	die "ERROR: ARG1 must be an existing folder. Please create before!"
fi 

INSTDIR=$1

# Path for python, ansible, sources, logs
ENV_ROOT=$INSTDIR/ansible_env
ENV_SRC=$ENV_ROOT/src
ENV_LOG=$ENV_ROOT/log
ENV_LOCALPYTHON=$ENV_ROOT/localpython

# path for Ansibles virtualenv 
ANSIBLE_VE=$INSTDIR/ansible_ve

# https://www.openssl.org/source/openssl-1.0.2k.tar.gz
OPENSSL_TGZ=/tmp/openssl-1.0.2k.tar.gz
# https://pypi.python.org/pypi/virtualenv/15.1.0#downloads
VIRTUALENV_TGZ=/tmp/virtualenv-15.1.0.tar.gz
# https://www.python.org/ftp/python/2.7.9/Python-2.7.9.tgz
PYTHON_TGZ=/tmp/Python-2.7.9.tgz
# http://releases.ansible.com/ansible/ansible-2.2.1.0.tar.gz
ANSIBLE_TGZ=/tmp/ansible-2.2.1.0.tar.gz

# dirnames after untaring
OPENSSL_D=$(basename $OPENSSL_TGZ | sed 's/\(.*\).tar.gz/\1/')
VIRTUALENV_D=$(basename $VIRTUALENV_TGZ | sed 's/\(.*\).tar.gz/\1/')
PYTHON_D=$(basename $PYTHON_TGZ | sed 's/\(.*\).tgz/\1/')

function die() {
	echo "$1"
	exit 1
}


# print out all env vars for easier debugging
if [ "$1" == "env" ]; then 
	for v in ENV_ROOT ENV_SRC ENV_LOG ENV_LOCALPYTHON ANSIBLE_VE OPENSSL_TGZ VIRTUALENV_TGZ PYTHON_TGZ ANSIBLE_TGZ OPENSSL_D VIRTUALENV_D PYTHON_D; do 
		echo "export $v=${!v}"
	done 
	exit 0
fi 

echo "> Initialisation..."
# initial purge
rm -rf $ENV_ROOT/$OPENSSL_D
rm -rf $ENV_ROOT/$PYTHON_D

# initialisation
mkdir -p $ENV_SRC
mkdir -p $ENV_LOG

# source file check
for s in $OPENSSL_TGZ $VIRTUALENV_TGZ $PYTHON_TGZ $ANSIBLE_TGZ; do 
	[ ! -r $s ] && die "ERROR: Source file $s is not available. Download first!"
done


function main() {
	pushd $ENV_SRC > /dev/null
	inst_openssl
	inst_python
	inst_venv
	create_venv
	inst_ansible
	tidyup
}

#################################
# compile OpenSSL
function inst_openssl() {
	echo "> compile OpenSSL..."
	tar -xzf $OPENSSL_TGZ
	pushd $OPENSSL_D  > /dev/null
	./config --prefix=$ENV_ROOT/$OPENSSL_D shared --openssldir=$ENV_ROOT/$OPENSSL_D/openssl &> $ENV_LOG/$OPENSSL_D.log
	make &> $ENV_LOG/$OPENSSL_D.log
	make install &> $ENV_LOG/$OPENSSL_D.log

	[ $? == 0 ] || die "ERROR: OpenSSL compilation failed."
	ln -s $ENV_ROOT/$OPENSSL_D $ENV_ROOT/openssl
	[ -d $ENV_ROOT/$OPENSSL_D ] || die "ERROR: OpenSSL lib path cannot be found. "
	echo "OK: OpenSSL installed in $ENV_ROOT/$OPENSSL_D."
	popd  > /dev/null
}

#################################
# compile Python with custom OpenSSL 
function inst_python() {
	echo "> compile Python..."
	tar -xzf $PYTHON_TGZ
	pushd $PYTHON_D  > /dev/null
	
	export LDFLAGS=-"Wl,-rpath=$ENV_ROOT/openssl/lib -L$ENV_ROOT/openssl/lib -L$ENV_ROOT/openssl/lib64/"
	export LD_LIBRARY_PATH="$ENV_ROOT/openssl/lib/:$ENV_ROOT/openssl/lib64"
	export CPPFLAGS="-I$ENV_ROOT/openssl/include -I$ENV_ROOT/openssl/include/openssl"
	sed -i "s%#SSL=/usr/local/ssl%SSL=${ENV_ROOT}/openssl \n_ssl _ssl.c -DUSE_SSL -I$\(SSL\)/include -I$\(SSL\)/include/openssl -L$\(SSL\)/lib -lssl -lcrypto%" Modules/Setup.dist
	cp Modules/Setup.dist Modules/Setup
	./configure --prefix=$ENV_LOCALPYTHON &> $ENV_LOG/$PYTHON_D.log
	make &> $ENV_LOG/$PYTHON_D.log
	make install &> $ENV_LOG/$PYTHON_D.log

	[ -x $ENV_LOCALPYTHON/bin/python ] || die "ERROR: Python installation in $ENV_LOCALPYTHON failed!"
	echo "OK: Python version installed:"
	$ENV_LOCALPYTHON/bin/python --version
	popd  > /dev/null
}
#################################
# install virtualenv (using the custom Python)
function inst_venv() {
	echo "> install Virtualenv..."
	tar -xzf $VIRTUALENV_TGZ
	pushd $VIRTUALENV_D  > /dev/null
	$ENV_LOCALPYTHON/bin/python setup.py install &> $ENV_LOG/$VIRTUALENV_D.log
	echo "OK. "
	popd   > /dev/null
}

#################################
# create virtualenv for Ansible with custom Python/custom OpenSSL
function create_venv() {
	echo "> create virtualenv for Ansible in $ANSIBLE_VE..."
	rm -rf $ANSIBLE_VE
	pushd $VIRTUALENV_D  > /dev/null
	./virtualenv.py $ANSIBLE_VE -p $ENV_LOCALPYTHON/bin/python &> $ENV_LOG/ansible_ve.log
	# save ppath
	echo "export OLD_PYTHONPATH=$PYTHONPATH"  >> $ANSIBLE_VE/bin/activate
	# make new ppath exclusive
	echo "export PYTHONPATH=$ENV_LOCALPYTHON" >> $ANSIBLE_VE/bin/activate
	# restore ppath 
	echo "export PYTHONPATH=$OLD_PYTHONPATH"  >> $ANSIBLE_VE/bin/postdeactivate
	[ -r $ANSIBLE_VE/bin/activate ] || die "ERROR: Virtualenv could not be created!"
	echo "OK: virtualenv created. "
	popd  > /dev/null
}
#################################
# install Ansible into virtualenv via pip/tgz
function inst_ansible() {
	echo "> Ansible installation..."
	pushd $ANSIBLE_VE  > /dev/null
	. bin/activate
	pip install $ANSIBLE_TGZ  --ignore-installed &> $ENV_LOG/ansible.log
	$ANSIBLE_VE/bin/ansible --version 
	[ $? -gt 0 ] && die "ERROR: Ansible installation failed!"
	echo "OK: Ansible installation finished. "
}

function tidyup() {
	rm -rf $ENV_SRC 
}

main
