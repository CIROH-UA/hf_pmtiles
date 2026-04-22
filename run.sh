#!/bin/bash
docker build --build-context local_copy=/mnt/raid/code/CIROH-UA/community_hf_patcher --build-context raw_copy=/home/josh/Documents/lynker-spatial/v2.2/ -t hf . && \
docker run -d --name hf_map hf sleep infinity && \
docker cp hf_map:/mbtiles/merged/all_flowpaths.pmtiles ./all_flowpaths.pmtiles && \
docker cp hf_map:/mbtiles/merged/all_divides.pmtiles ./all_divides.pmtiles && \
docker cp hf_map:/mbtiles/merged/all_gages.pmtiles ./all_gages.pmtiles && \
docker cp hf_map:/mbtiles/merged/all_hydrolocations.pmtiles ./all_hydrolocations.pmtiles && \
docker kill hf_map && \
docker rm hf_map && \
aws s3 cp ./all_flowpaths.pmtiles s3://communityhydrofabric/map/kepler/flowpaths.pmtiles && \
aws s3 cp ./all_divides.pmtiles s3://communityhydrofabric/map/kepler/divides.pmtiles && \
aws s3 cp ./all_gages.pmtiles s3://communityhydrofabric/map/kepler/gages.pmtiles && \
aws s3 cp ./all_hydrolocations.pmtiles s3://communityhydrofabric/map/kepler/hydrolocations.pmtiles
