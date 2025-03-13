set -e

RAM_SIZE=8388608
ROM_SIZE=8192
ROM_START=268435456
BIN_NAME="boot.bin"

#make the boot binary
(cd ./src/boot && make RAM_SIZE=$RAM_SIZE ROM_SIZE=$ROM_SIZE ROM_START=$ROM_START BIN_NAME=$BIN_NAME)

#call zig build with the newly made binary
zig build -Dramsize=$RAM_SIZE -Dromsize=$ROM_SIZE -Dromstart=$ROM_START -Dbootpath="./out/"$BIN_NAME
cp ./zig-out/bin/Tent ./out/Tent