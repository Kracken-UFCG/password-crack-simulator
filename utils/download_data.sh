#!/bin/bash

DATA_DIR="data"

mkdir -p "$DATA_DIR"

wget -O "$DATA_DIR/rockyou.txt.zip" https://github.com/RykerWilder/rockyou.txt/raw/main/rockyou.txt.zip

unzip "$DATA_DIR/rockyou.txt.zip" -d "$DATA_DIR"

rm "$DATA_DIR/rockyou.txt.zip"
