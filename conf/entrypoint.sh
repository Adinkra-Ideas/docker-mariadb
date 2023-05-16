#!/bin/sh

set -e

MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD:-docker}
MARIADB_DATABASE=${MARIADB_DATABASE:-}
MARIADB_USER=${MARIADB_USER:-}
MARIADB_PASSWORD=${MARIADB_PASSWORD:-}
MYSQLD_ARGS=${MYSQLD_ARGS:-}

chown -R mysql:mysql /var/lib/mysql

# make sure that the run directory exists & has the right permissions
if [ ! -d "/run/mysqld" ]
then
  mkdir /run/mysqld
  chown mysql:mysql /run/mysqld
fi

# only bootstrap(Add primary DB node to be used as reference point 
# by the rest)
# if /var/lib/mysql is empty
if [ ! "$(ls -A /var/lib/mysql)" ];
then
  echo "==================================="
  echo "Bootstrapping system database..." ;echo

  # Initialize the mariadb directory and create the system tables
  # if they do not exist. Mariadb uses system tables to manage roles
  # privileges and plugins. user mysql(name of our user account on host machine)
  # will chown the files created bz mysqld
  /usr/bin/mysql_install_db ${MYSQLD_ARGS} --user=mysql --datadir=/var/lib/mysql/

  echo "System install complete!"
  echo "===================================";echo

  echo "==================================="
  echo "Bootstrapping Arch(AKA first, privilege, system) database...";echo

  # create a sql file for use as bootstrap DB node
  # create a sql file used to bootstrap the environment
  # mktemp cmd creates and returns a tmp file that is
  # only readable and writable by the owner
  TEMP_FILE="$(mktemp)"
  if [ ! -f "${TEMP_FILE}" ]
  then
    echo "error: unable to create temp file; exiting"
    exit 1
  fi

  cat << EOF > "${TEMP_FILE}"
# drop test database
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS mysql;
# use the mysql DB as default for subsequent statements
USE mysql;
FLUSH PRIVILEGES;
# update user access to allow root login from all hosts.
# Host can be any number/value of string (%)
# QUICK NOTE: % wildcard means any number of string. _ wildcard means
# single char in Mariadb SQL
CREATE OR REPLACE USER 'root'@'localhost' IDENTIFIED BY "${MARIADB_ROOT_PASSWORD}";
CREATE OR REPLACE USER 'root'@'%' IDENTIFIED BY "${MARIADB_ROOT_PASSWORD}";
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
EOF

    if [ -n "${MARIADB_DATABASE}" ];
    then
	echo "CREATE DATABASE IF NOT EXISTS ${MARIADB_DATABASE} CHARACTER SET utf8 COLLATE utf8_general_ci;" >> ${TEMP_FILE}

    # the -n flag makes the if condition check if the var has strlen > 0
    # If true, then we create(if not zet exist) and grant all DB privilege to ${MARIADB_USER} 
	if [ -n "${MARIADB_USER}" ]
	then
		echo "CREATE OR REPLACE USER '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';" >> ${TEMP_FILE}
		echo "CREATE OR REPLACE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';" >> ${TEMP_FILE}
		echo "GRANT ALL ON ${MARIADB_DATABASE}.* to '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';" >> ${TEMP_FILE}
		echo "GRANT ALL ON ${MARIADB_DATABASE}.* to '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';" >> ${TEMP_FILE}
	fi
    fi

  # Send the buffered DB creation request 
  # The --bootstrap option tells mysqld that we're creating the 
  # Arch database thus it should set the szstem tables up so that
  # the system can become usable(AKA permit adding DB and USERS)
  /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 ${MYSQLD_ARGS} < "${TEMP_FILE}"
  rm -f "${TEMP_FILE}"

  echo;echo "Bootstrap of MariaDB complete"
  echo "===================================";echo
else
  echo "Bootstrapping MariaDB not neccessary; skipping.";echo
fi

echo "==================================="
echo "Launching MariaDB...";echo

# Since this bash script was called using ARGVS,(AKA
# CMD in Dockerfile becomes ARGVs for ENTRYPOINT)
# now execute those ARGVS by doing "exec ARGVS"
# pulling them into process ID 1
exec "$@" --user=mysql ${MYSQLD_ARGS}
