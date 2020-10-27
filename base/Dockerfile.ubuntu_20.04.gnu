FROM ubuntu:20.04
RUN apt-get update -y && \
   DEBIAN_FRONTEND=noninteractive \
   apt-get install -y --no-install-recommends \
           autoconf \
           automake \
           cmake \
           curl \
           g++ \
           gcc \
           gfortran \
           git \
           libcurl4-openssl-dev \
           libmpich-dev \
           libtool \
           libexpat1-dev \
           make \
           pkg-config \
           vim \
           wget \
           unzip \
           python3-dev \
           python3-pip

RUN ln -s /usr/bin/python3 /usr/bin/python

RUN useradd -ms /bin/bash builder
WORKDIR /home/builder

USER builder

CMD ["/bin/bash"]
