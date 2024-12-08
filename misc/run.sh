docker build -t nvim-deck .

dir=$(dirname $0)

if [ ! -d $dir/.config ]; then
  mkdir $dir/.config
  chmod 777 $dir/.config
fi
if [ ! -d $dir/.cache ]; then
  mkdir $dir/.cache
  chmod 777 $dir/.cache
fi
if [ ! -d $dir/.local ]; then
  mkdir $dir/.local
  chmod 777 $dir/.local
fi

docker run -it \
  -v $(PWD)/gitconfig:/root/.gitconfig \
  -v $(PWD)/..:/root/nvim-deck \
  -v $(PWD)/.cache:/root/.cache \
  -v $(PWD)/.config:/root/.config \
  -v $(PWD)/.local:/root/.local \
  -w /root/nvim-deck \
  nvim-deck -u /root/nvim-deck/misc/init.lua

