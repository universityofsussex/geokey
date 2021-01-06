#########
# BUILD #
#########
FROM debian:buster-slim as build
ENV	PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV HOME=/home/app \
		APP_HOME=/home/app/web \
		PACKAGES="libxml2-dev libxslt1-dev libffi-dev libmagic-dev python-gdal binutils curl g++ ffmpeg python2 python-setuptools python-pip imagemagick libgdal-dev libpython2-dev libmagickcore-dev libmagickwand-dev curl wget nodejs postgis postgresql postgresql-contrib" \
		DEBIAN_FRONTEND="noninteractive"
RUN apt-get update \
		&& apt-get install --no-install-recommends -y $PACKAGES \
		&& mkdir -p /usr/src/app 
WORKDIR /usr/src/app
ADD ./geokey/  .
ADD ./settings .
RUN sed -i 's/\(<policy domain="coder" rights=\)"none" \(pattern="PDF" \/>\)/\1"read|write"\2/g' /etc/ImageMagick-6/policy.xml \
    && gdal-config --version \
    && export C_INCLUDE_PATH=/usr/include/gdal \
    && export CPLUS_INCLUDE_PATH=/usr/include/gdal \
		&& pip install wheel \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels install gdal==2.4.0 \
		&& pip wheel --no-cache-dir --wheel-dir /usr/src/app/wheels -r requirements.txt \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels install gunicorn \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels install futures \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels install -e .

##########
## Final #
##########
FROM debian:buster-slim 
ENV HOME=/home/django-data \
		DEBIAN_FRONTEND="noninteractive" \
		PACKAGES_FINAL="libxml2-dev libxslt1-dev libmagic1 python2 python-setuptools python-pip nodejs python-gdal libffi6"
RUN groupadd -r --gid 10295 django-data \ 
		&& adduser --home $HOME --disabled-password --uid 10295 --gid 10295 --gecos "" django-data 
WORKDIR $HOME
COPY --from=build /usr/src/app .
RUN apt-get -y update \
		&& apt-get install --no-install-recommends -y $PACKAGES_FINAL \
		&& apt-get clean autoclean \
		&& apt-get autoremove --yes \
		&& rm -rf /var/lib/{apt,dpkg,cache,log}/ \
		&& pip install --no-deps --no-cache --upgrade pip \
		&& pip install --no-deps --no-cache $HOME/wheels/* \
    && pip install --no-cache geokey-epicollect \
    && pip install --no-cache geokey-dataimports \
    && pip install --no-cache geokey-export \
    && pip install --no-cache  geokey-sapelli \
    && pip install --no-cache   geokey-webresources \
		&& rm -rf wheels \
    && mkdir /run/gunicorn \
    && chown django-data:django-data /run/gunicorn \
    && chown django-data:django-data . -R
USER 10295
CMD yes | /usr/bin/python2 manage.py collectstatic ; /usr/local/bin/gunicorn  --workers=2 --threads=4 --worker-class=gthread --log-file=-  -b unix:/run/gunicorn/gunicorn.sock wsgi

