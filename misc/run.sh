docker build -t nvim-deck .

docker run -it \
  -v $(PWD)/..:/root/nvim-deck \
  -u $(id -u):$(id -g) \
  -w /root/nvim-deck \
  nvim-deck -u /root/nvim-deck/misc/init.lua

