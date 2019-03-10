FROM debian:latest
MAINTAINER tom@harhar.net

ENV DEBIAN_FRONTEND noninteractive

RUN echo "Europe/Berlin" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

RUN apt-get update && \
    apt-get -y dist-upgrade

RUN apt-get -y install locales psmisc supervisor cron rsyslog wget mrtg apache2 netcat

RUN dpkg-reconfigure -f noninteractive locales
RUN sed --in-place '/de_DE.UTF-8/s/^#//' /etc/locale.gen
RUN locale-gen de_DE.UTF-8  
ENV LANG de_DE.UTF-8  
ENV LANGUAGE de_DE:de  
ENV LC_ALL de_DE.UTF-8

COPY assets/upnp2mrtg.sh /usr/local/bin
COPY assets/mrtg.cfg /etc
COPY assets/mrtg-cron /etc/cron.d/mrtg

RUN rm /var/www/html/index.html

CMD /bin/sh -c "service cron start; service apache2 start; while true; do echo Hello world; sleep 3600; done"

