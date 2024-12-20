FROM httpd:2.4.59

RUN apt-get update
RUN apt-get install -y libcgi-pm-perl libcapture-tiny-perl libdatetime-perl libcapture-tiny-perl libgeo-ip-perl
RUN apt-get install -y libjson-xs-perl libintl-perl libxml-rss-perl libdatetime-format-strptime-perl make gettext locales

# Generate locales for translations
RUN echo "et_EE.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen

COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf-extra
RUN cat /usr/local/apache2/conf/httpd.conf-extra >> /usr/local/apache2/conf/httpd.conf

COPY ./htdocs/  /usr/local/apache2/htdocs/
COPY ./cgi-bin/ /usr/local/apache2/cgi-bin/
COPY ./config/  /usr/local/apache2/config/

WORKDIR /usr/local/apache2/config/
RUN make update-mo && make install
WORKDIR /usr/local/apache2/

# Set permissions to www-data, there's seems to be no other way to do that
RUN sed -i 's/^exec /chown -R www-data:www-data \/srv\/data\n\nexec /' /usr/local/bin/httpd-foreground
