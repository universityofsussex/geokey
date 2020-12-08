#########
# BUILD #
#########
FROM debian:buster-slim as build
ENV	PYTHONDONTWRITEBYTECODE 1 
ENV	PYTHONUNBUFFERED 1 
ENV MEMORYMAPPER_VERSION="master" \
		HOME=/home/app \
		APP_HOME=/home/app/web \
		PACKAGES="python-gdal binutils  g++ ffmpeg python2 python-setuptools python-pip imagemagick libgdal-dev libpython2-dev libmagickcore-dev libmagickwand-dev curl wget nodejs postgis postgresql postgresql-contrib" \
		DEBIAN_FRONTEND="noninteractive"
RUN apt-get update \
		&& apt-get install --no-install-recommends -y $PACKAGES \
		&& mkdir -p /usr/src/app \
		&& sed -i 's/\(<policy domain="coder" rights=\)"none" \(pattern="PDF" \/>\)/\1"read|write"\2/g' /etc/ImageMagick-6/policy.xml
WORKDIR /usr/src/app
ADD .  .
RUN gdal-config --version \
    && export C_INCLUDE_PATH=/usr/include/gdal \
    && export CPLUS_INCLUDE_PATH=/usr/include/gdal \
		&& pip install wheel \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels install gdal==2.4.0 \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels install gunicorn \
		&& pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels install -e .

##########
## Final #
##########
FROM debian:buster-slim 
ENV HOME=/home/django-data \
		DEBIAN_FRONTEND="noninteractive" \
		PACKAGES_FINAL="python2 python-setuptools python-pip nodejs "
RUN groupadd -r --gid 295 django-data \ 
		&& adduser --home $HOME --disabled-password --uid 295 --gid 295 --gecos "" django-data 
WORKDIR $HOME
COPY --from=build /usr/src/app .
COPY docker_settings.py  local_settings.example/settings.py
RUN apt-get -y update \
		&& apt-get install --no-install-recommends -y $PACKAGES_FINAL \
		&& apt-get clean autoclean \
		&& apt-get autoremove --yes \
		&& rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && mv local_settings.example local_settings \
		&& pip install --no-deps --no-cache --upgrade pip \
		&& pip install --no-deps --no-cache $HOME/wheels/* \
		&& rm -rf wheels \
    && chown django-data:django-data . -R
USER 295
CMD /usr/bin/python2 manage.py collectstatic ; /usr/local/bin/gunicorn  --workers=2 --threads=4 --worker-class=gthread --log-file=- -b 0.0.0.0:8000  
