FROM alpine:3.16

#latest mariadb stable for Alpine 3.16
RUN apk update && \
        apk add --no-cache mariadb=10.6.13-r0 mariadb-client mariadb-server-utils && \
	deluser mysql && \
	addgroup -g 507 mysql && \
	adduser -D -h /var/lib/mysql/ -u 507 -g mysql -G mysql -s /sbin/nologin mysql && \
	mkdir /run/mysqld/ && \
	chown -R mysql:mysql /run/mysqld/ /var/lib/mysql/ /etc/mysql/ && \
	sed -i 's/^skip-networking/#skip-networking/' /etc/my.cnf.d/mariadb-server.cnf && \
	sed -i 's/^#bind-address=0.0.0.0/bind-address=0.0.0.0/' /etc/my.cnf.d/mariadb-server.cnf

#for editing files
RUN apk add --no-cache nano

# Put entrypoint script file inside the Image
COPY --chmod=0755 conf/entrypoint.sh /

#
ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/mysqld"]

