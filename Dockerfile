####
# Netflow collector and local processing container
# using NFSen and NFDump for processing. This can
# be run standalone or in conjunction with a analytics
# engine that will perform time based graphing and
# stats summarization.
# run container : docker run -p 11022:22 -p 6080:80 -p 1555:1555/udp -p 1559:1559/udp -p 4739:4739/udp -p 6343:6343/udp -p 9996:9996/udp -d  -i -t --name nfsen --hostname nfsen registry.iutbeziers.fr/nfsen:porttracker 
###

FROM registry.iutbeziers.fr/debianiut
MAINTAINER pouchou <jean-marc.pouchoulon@iutbeziers.fr> # adapted from Brent Salisbury <brent.salisbury@gmail.com https://github.com/nerdalert/nfsen-dockerized

RUN apt-get update
RUN apt-get install -y \
    gcc \
    flex \
    bison \
    rrdtool \
    mrtg \
    apache2 \
    tcpdump \
    wget \
    php5 \
    apache2 \
    librrd-dev \
    libpcap-dev \
    libapache2-mod-php5 \
    php5-common \
    libio-socket-inet6-perl \
    libio-socket-ssl-perl \
    libmailtools-perl \
    librrds-perl \
    librrdp-perl \
    libwww-perl \
    libipc-run-perl \
    perl-base \
    libsys-syslog-perl \
    supervisor \
    net-tools \
    rsyslog \
    libbz2-dev \
    vim 

# Cleanup apt-get cache
RUN apt-get clean

# Apache
EXPOSE 80
# NetFlow port to expose 16 PC in class room - just nat them in run or with docker-compose
EXPOSE 1555
EXPOSE 1556
EXPOSE 1557
EXPOSE 1558
EXPOSE 1559
EXPOSE 1561
EXPOSE 1562
EXPOSE 1563
EXPOSE 1564
EXPOSE 1565
EXPOSE 1566
EXPOSE 1567
EXPOSE 1568
EXPOSE 1569
EXPOSE 1570
EXPOSE 1571
EXPOSE 1572
EXPOSE 1573
EXPOSE 1574
# IPFIX
EXPOSE 4739
# sFlow
EXPOSE 6343
# nfsen src ip src node mappings per example
EXPOSE 9996

# mk some dirs
RUN mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/supervisor

# Example ENV variable injection if you want to add collector addresses
ENV NFSEN_VERSION 1.3.7
ENV NFDUMP_VERSION 1.6.15
# 1.3.16  nfdumplib  are not in LD_LIBRARY_PATH - nfsen failed to compile
ENV LD_LIBRARY_PATH /usr/local/lib

# Install NFDump (note the random redirected DL server from sourceforge. Their redirects are awful
# so using the only 302 redirect that is the closest to almost working every time...
WORKDIR /usr/local/src
COPY nfdump-${NFDUMP_VERSION}.tar.gz /usr/local/src/nfdump-${NFDUMP_VERSION}.tar.gz
RUN cd /usr/local/src && \
#    wget  http://iweb.dl.sourceforge.net/project/nfdump/stable/nfdump-${NFDUMP_VERSION}/nfdump-${NFDUMP_VERSION}.tar.gz && \
	tar xvfz  nfdump-${NFDUMP_VERSION}.tar.gz && cd nfdump-${NFDUMP_VERSION}/ && \
	./configure \
	--enable-nfprofile \
        --enable-readpcap \
        --enable-nftrack \
        --enable-nfpcapd \
        --enable-compat15 \
	--with-rrdpath=/usr/bin \
	--enable-sflow && \
	make && make install

RUN cp /usr/local/lib/libnfdump-1.6.15.so /usr/lib/ # bug 1.6.15

# Configure php with the systems timezone, modifications are tagged with the word 'NFSEN_OPT' for future ref
# Recommended leaving the timezone as UTC as NFSen and NFCapd timestamps need to be in synch.
# Timing is also important for the agregates time series viewer for glabal visibility and analytics.
RUN sed -i 's/^;date.timezone =/date.timezone \= \"Europe\/Paris"/g' /etc/php5/apache2/php.ini
#RUN sed -i '/date.timezone = "UTC\"/i ; NFSEN_OPT Adjust your timezone for nfsen' /etc/php5/apache2/php.ini
RUN sed -i 's/^;date.timezone =/date.timezone \= \"Europe\/Paris"/g' /etc/php5/cli/php.ini
#RUN sed -i '/date.timezone = "UTC\"/i ; NFSEN_OPT Adjust your timezone for nfsen' /etc/php5/cli/php.ini

# Configure NFSen config files
RUN mkdir -p /data/nfsen
WORKDIR /data
ADD nfsen-${NFSEN_VERSION}.tar.gz .
RUN sed -i 's/"www";/"www-data";/g' nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
RUN sed -i 's/"\/var\/www\/nfsen\/";/"\/var\/www\/html\/nfsen";/g' nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
# Example how to fill in any flow source you want using | as a delimiter. Sort of long and gross though.
# Modify the pre-defined NetFlow v5/v9 line matching the regex 'upstream1'
RUN sed -i  "s|'upstream1'    => { 'port' => '9995', 'col' => '#0000ff', 'type' => 'netflow' },|'bb'  => { 'port' => '1559', 'col' => '#50B718', 'type' => 'netflow' },|g"  nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
RUN sed  -i "/%sources/a \\    'nat' => { 'port' => '1555', 'col' =>  '#B71818', 'type' => 'netflow' }," nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
# Bind port 6343 and an entry for  sFlow collection
RUN sed  -i "/%sources/a \\    'sflow-global'  => { 'port' => '6343', 'col' => '#0000ff', 'type' => 'sflow' }," nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
# Bind port 4739 and an entry for IPFIX collection. E.g. NetFlow v10
RUN sed  -i "/%sources/a \\    'ipfix-global'  => { 'port' => '4739', 'col' => '#0000ff', 'type' => 'netflow' }," nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
# reduce BUFFLEN accelerate graph output - do not use in production 
RUN sed -i   "/\$BUFFLEN = 200000;/c \$BUFFLEN = 2000;"  nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
# Add an account for NFSen as a member of the apache group
RUN useradd -d /data/nfsen -G www-data -m -s /bin/false netflow
#RUN sed -i 's/$WWWUSER  = "www-data";/$WWWUSER  = "netflow";/g' nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf

# portracker plugin activation
RUN sed -i   "/'demoplugin'/c [ '*',     'PortTracker' ],"  nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
# peer1 peer2 have no colors that breaks drawing graph - delete them 
RUN sed -i   "/    'peer1'        => { 'port' => '9996', 'IP' => '172.16.17.18' },/d"  nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf
RUN sed -i   "/    'peer2'        => { 'port' => '9996', 'IP' => '172.16.17.19' },/d"  nfsen-${NFSEN_VERSION}/etc/nfsen-dist.conf

COPY PortTracker.php /var/www/html/nfsen/plugins/PortTracker.php
COPY PortTracker.pm  /data/nfsen/plugins/PortTracker.pm

# Run the nfsen installer
WORKDIR /data/nfsen-${NFSEN_VERSION}
RUN perl ./install.pl etc/nfsen-dist.conf || true
RUN sleep 3

RUN ["chown","netflow:www-data","/var/www/html/nfsen/plugins/PortTracker.php"]
RUN ["chown","netflow:www-data","/data/nfsen/plugins/PortTracker.pm"]
RUN ["chown","netflow:www-data","/var/www/html/nfsen/"]
RUN mkdir -p /data/ports-db
RUN ["chown","netflow:www-data","/data/ports-db"]
USER netflow
RUN /usr/local/bin/nftrack -I -d /data/ports-db 
USER root
RUN ["chown","-R","netflow:www-data","/data/ports-db"]
RUN ln -s /var/www/html/nfsen/nfsen.php /var/www/html/nfsen/index.php
RUN chmod 775 /data/ports-db
RUN chmod 664 /data/ports-db/*


WORKDIR /
# Add startup script for nfsen profile init
ADD ./start.sh /data/start.sh
# flow-generator binary for testing
ADD ./flow-generator /data/flow-generator
ADD	./supervisord.conf /etc/supervisord.conf

CMD bash -C '/data/start.sh'; '/usr/bin/supervisord'
