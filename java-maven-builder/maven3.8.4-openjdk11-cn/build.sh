#!/usr/bin/env bash

cur_dir=$(pwd)
kit_dir="${cur_dir}/kit"

cd "${kit_dir}" || exit
tar -xzf "${kit_dir}/apache-maven-3.8.4-bin.tar.gz"
tar -xzf "${kit_dir}/microsoft-jdk-11.0.13.8.1-linux-x64.tar.gz"
mv "${kit_dir}/jdk-11.0.13+8" "${kit_dir}/jdk-11.0.13.8"

cd "${cur_dir}" || exit
docker build -t "ayakurayuki/java-maven-builder:maven3.8.4-openjdk11-cn" .

rm -rf "${kit_dir}/apache-maven-3.8.4"
rm -rf "${kit_dir}/jdk-11.0.13.8"
