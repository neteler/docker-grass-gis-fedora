# Docker image for Cloud usage with Python3 and no GUI
# https://trac.osgeo.org/grass/wiki/Python3Support#Howtotest

## full image
#FROM fedora
#ENV MYDNF dnf

## Alternative: layered approach
FROM registry.fedoraproject.org/fedora-minimal:latest
ENV MYDNF microdnf

MAINTAINER Markus Neteler <neteler@mundialis.de>

RUN $MYDNF update -y

# GRASS GIS compile dependencies
RUN $MYDNF -y install gcc gcc-c++ bison flex make ncurses-devel \
             bzip2-devel libzstd libzstd-devel \
             proj-epsg proj-devel proj-nad \
             gdal gdal-devel gdal-python \
             doxygen subversion sqlite-devel xml2 \
             atlas-devel lapack-devel openblas-devel \
             geos geos-devel fftw-devel netcdf netcdf-devel libpng-devel \
             postgresql-devel libtiff-devel python3 python3-devel python3-six python3-numpy \
             python3-dateutil python3-pillow python3-sphinx \
             && $MYDNF clean all

# dirty hack to enforce python3 (/usr/bin/python points to /usr/bin/python2)
RUN rm -f /usr/bin/python && ln -s /usr/bin/python3 /usr/bin/python

RUN mkdir -p /code/grassgis

# add repository files to the image
COPY . /code/grassgis

WORKDIR /code/grassgis

# Set gcc/g++ environmental variables for GRASS GIS compilation, without debug symbols
ENV MYCFLAGS "-O2 -std=gnu99 -m64"
ENV MYLDFLAGS "-s"
# CXX stuff:
ENV LD_LIBRARY_PATH "/usr/local/lib"
ENV LDFLAGS "$MYLDFLAGS"
ENV CFLAGS "$MYCFLAGS"
ENV CXXFLAGS "$MYCXXFLAGS"

# compile and install GRASS GIS
ENV NUMTHREADS=2
RUN ./configure \
   --with-cxx \
   --enable-largefile \
   --with-proj --with-proj-share=/usr/share/proj \
   --with-gdal=/usr/bin/gdal-config \
   --with-geos \
   --with-sqlite \
   --with-zstd \
   --with-fftw \
   --with-netcdf \
   --with-blas --with-blas-includes=/usr/include/atlas-x86_64-base/ \
   --with-lapack --with-lapack-includes=/usr/include/atlas-x86_64-base/ \
   --with-postgres --with-postgres-includes="/usr/include/pgsql" \
   --without-freetype \
   --without-nls \
   --without-cairo \
   --without-opengl \
   --without-liblas \
   --without-mysql \
   --without-odbc \
   --without-openmp \
   --without-ffmpeg \
    && make -j $NUMTHREADS && make install && ldconfig

# enable simple grass command regardless of version number
RUN ln -s /usr/local/bin/grass* /usr/local/bin/grass

# revoke dirty hack to enforce python3, i.e. restore python2 link
RUN rm -f /usr/bin/python && ln -s /usr/bin/python2 /usr/bin/python

# create a user
RUN useradd -m -U grass

VOLUME ["/data"]

# switch the user
USER grass

WORKDIR /data

# Ensure the SHELL is picked up by grass.
ENV SHELL /bin/bash

# All commands are executed by grass.
ENTRYPOINT ["grass"]

# Output GRASS GIS version by default.
CMD ["--help]

