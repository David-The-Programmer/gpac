#!/bin/bash

version=$(git describe)
release_dir="gpac_${version}_x86_64"
release_tar_file="${release_dir}.tar.gz"

mkdir -p ${release_dir}
gleam build && gleam run -m gleescript -- --out=${release_dir}
tar -cvzf ${release_tar_file} ${release_dir}
rm -r ${release_dir}

