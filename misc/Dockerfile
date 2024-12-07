FROM ubuntu

ARG BUILD_APT_DEPS="ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip git binutils wget"
ARG TARGET=nightly

RUN apt update && apt upgrade -y && \
  apt install -y ${BUILD_APT_DEPS} && \
  git clone https://github.com/neovim/neovim.git /tmp/neovim && \
  cd /tmp/neovim && \
  git fetch --all --tags -f && \
  git checkout ${TARGET} && \
  make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=/usr/local/ && \
  make install && \
  strip /usr/local/bin/nvim

RUN apt-get install -y ripgrep

# Setup /root as homedir.
RUN chmod -R 777 /root
ENV HOME /root
WORKDIR /root

ENTRYPOINT ["/usr/local/bin/nvim"]
