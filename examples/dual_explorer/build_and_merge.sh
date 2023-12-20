echo "BUILDING AND MERGING BINARIES TO SINGLE APPLICATION"

xmake -j all

APP_NAME="app_dual_uac"

# Make new "merged" xe file
cp "bin/NODE_0/${APP_NAME}_NODE_0.xe" "bin/${APP_NAME}.xe"

# split the secondary tile binary
cd bin/NODE_1
xobjdump --split "${APP_NAME}_NODE_1.xe"
cd -

#replace both tiles of node 1 from other binary
# --replace <node,tile,file> | : Replace sector data from <file> in the executable <tilereference,file>
xobjdump "bin/${APP_NAME}.xe" -r 1,0,bin/NODE_1/image_n1c0_2.elf
xobjdump "bin/${APP_NAME}.xe" -r 1,1,bin/NODE_1/image_n1c1_2.elf
