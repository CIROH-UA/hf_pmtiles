# syntax=docker/dockerfile:1
FROM ubuntu AS base
RUN apt update && apt install -y nala
RUN nala install -y build-essential libsqlite3-dev zlib1g-dev wget gdal-bin git python3-pip libsqlite3-mod-spatialite sqlite3

WORKDIR /tippecanoe
RUN git clone --single-branch --depth=1 https://github.com/felt/tippecanoe.git \
&& cd tippecanoe \
&& make -j \
&& make install

WORKDIR /pmtiles
ADD https://github.com/protomaps/go-pmtiles/releases/download/v1.30.3/go-pmtiles_1.30.3_Linux_x86_64.tar.gz /pmtiles/pmtiles.tar.gz
RUN tar -xvf pmtiles.tar.gz
RUN mv pmtiles /usr/local/bin

COPY <<'EOF' /usr/bin/fix_ids
!#/bin/bash
ogrinfo $1 -sql "SELECT DisableSpatialIndex('divides','geom')"
ogrinfo $1 -sql "SELECT DisableSpatialIndex('flowpaths','geom')"
ogrinfo $1 -sql "SELECT DisableSpatialIndex('nexus','geom')"
sqlite3 $1 "UPDATE flowpaths SET divide_id = CAST(substr(divide_id,5) AS INTEGER), id = CAST(substr(id,4) AS INTEGER), toid = CAST(substr(toid,5) AS INTEGER);"
sqlite3 $1 "UPDATE divides SET divide_id = CAST(substr(divide_id,5) AS INTEGER), id = CAST(substr(id,4) AS INTEGER), toid = CAST(substr(toid,5) AS INTEGER);"
EOF
RUN chmod +x /usr/bin/fix_ids

COPY <<'EOF' /usr/bin/simplify_gage_data
!#/bin/bash
ogrinfo $1 -sql "SELECT DisableSpatialIndex('hydrolocations','geom')"
sqlite3 $1 "UPDATE hydrolocations SET id = CAST(substr(id,4) AS INTEGER);"
EOF
RUN chmod +x /usr/bin/simplify_gage_data

# remove as many strings as possible and convert to int where possible e.g. float meters to int cm will be much smaller
# The smaller we make these attributes, the more geometry we can keep in our tiles
COPY <<'EOF' /usr/bin/make_flowpath_tiles
!#/bin/bash
tippecanoe -z10 -Z2 -o flowpaths.mbtiles \
    --use-attribute-for-id=id \
    -l flowpaths -X\
    -y order -y divide_id -y toid -y \
    -T order:int -T divide_id:int -T toid:int \
    -aI  \
    -pS \
    --drop-by-attribute-as-needed=order \
    flowpaths.fgb -P
EOF
RUN chmod +x /usr/bin/make_flowpath_tiles

COPY <<'EOF' /usr/bin/make_divide_tiles
!#/bin/bash
min_zoom="${1:-4}"
tippecanoe -z10 -Z$min_zoom -o divides.mbtiles \
    --use-attribute-for-id=divide_id \
    -l divides -X \
    -y divide_id -y toid -y \
    -T divide_id:int -T toid:int \
    -M 300000 \
    --order-by="divide_id" \
    --drop-densest-as-needed \
    -S 5 \
    -aI  \
    -pS \
    divides.fgb -P
EOF
RUN chmod +x /usr/bin/make_divide_tiles

FROM base AS ak_to_fgb
# ak EPSG:3338
WORKDIR /fgb/ak
ADD --unpack https://communityhydrofabric.com/hydrofabrics/community/ak_nextgen.tar.gz /raw_hf/
RUN fix_ids /raw_hf/ak_nextgen.gpkg
RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 flowpaths.fgb /raw_hf/ak_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 divides.fgb /raw_hf/ak_nextgen.gpkg divides

# FROM base AS gl_to_fgb
# # great lakes canada region
# # gl divides flowpaths EPSG:3338       hydrolocations, pois EPSG:5070
# WORKDIR /fgb/gl
# ADD --unpack https://communityhydrofabric.com/hydrofabrics/community/gl_nextgen.tar.gz /raw_hf/
# RUN fix_ids /raw_hf/gl_nextgen.gpkg
# RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 flowpaths.fgb /raw_hf/gl_nextgen.gpkg flowpaths
# RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 divides.fgb /raw_hf/gl_nextgen.gpkg divides
# RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 hydrolocations.fgb /raw_hf/gl_nextgen.gpkg hydrolocations

FROM base AS hi_to_fgb
# hi ESRI:102007
WORKDIR /fgb/hi
ADD --unpack https://communityhydrofabric.com/hydrofabrics/community/hi_nextgen.tar.gz /raw_hf/
RUN fix_ids /raw_hf/hi_nextgen.gpkg
RUN ogr2ogr -s_srs ESRI:102007 -t_srs CRS:84 flowpaths.fgb /raw_hf/hi_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs ESRI:102007 -t_srs CRS:84 divides.fgb /raw_hf/hi_nextgen.gpkg divides

FROM base AS prvi_to_fgb
# prvi EPSG:6566
WORKDIR /fgb/prvi
ADD --unpack https://communityhydrofabric.com/hydrofabrics/community/prvi_nextgen.tar.gz /raw_hf/
RUN fix_ids /raw_hf/prvi_nextgen.gpkg
RUN ogr2ogr -s_srs EPSG:6566 -t_srs CRS:84 flowpaths.fgb /raw_hf/prvi_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs EPSG:6566 -t_srs CRS:84 divides.fgb /raw_hf/prvi_nextgen.gpkg divides

FROM base AS conus_to_fgb
# conus EPSG:5070
WORKDIR /fgb/conus
ADD --unpack https://communityhydrofabric.com/hydrofabrics/community/conus_nextgen.tar.gz /raw_hf/
RUN fix_ids /raw_hf/conus_nextgen.gpkg
RUN simplify_gage_data /raw_hf/conus_nextgen.gpkg
RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 flowpaths.fgb /raw_hf/conus_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 divides.fgb /raw_hf/conus_nextgen.gpkg divides
RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 hydrolocations.fgb /raw_hf/conus_nextgen.gpkg hydrolocations

FROM ak_to_fgb AS ak_to_mbtiles
RUN make_divide_tiles && make_flowpath_tiles

# FROM gl_to_fgb AS gl_to_mbtiles
# RUN make_divide_tiles && make_flowpath_tiles
# RUN tippecanoe -z10 -Z2 -r1 --cluster-distance=5 -o hydrolocations.mbtiles -l hydrolocations hydrolocations.fgb -P
# RUN tippecanoe -z10 -Z3 -r1 -j '{ "*": [ "any", [ "==", "hl_reference", "gages" ]] }' -o gages.mbtiles -l gages hydrolocations.fgb -P

FROM hi_to_fgb AS hi_to_mbtiles
RUN make_divide_tiles && make_flowpath_tiles

FROM prvi_to_fgb AS prvi_to_mbtiles
RUN make_divide_tiles && make_flowpath_tiles

FROM conus_to_fgb AS conus_to_mbtiles
RUN make_divide_tiles 7 && make_flowpath_tiles
RUN tippecanoe -z10 -Z2 -r1 --cluster-distance=5 -o hydrolocations.mbtiles -l hydrolocations hydrolocations.fgb -P
RUN tippecanoe -z10 -Z3 -r1 -j '{ "*": [ "any", [ "==", "hl_reference", "gages" ]] }' -o gages.mbtiles -l gages -y id -y hl_uri -y hl_reference -T id:int hydrolocations.fgb -P


FROM base AS merge_mbtiles
WORKDIR /mbtiles/merged
COPY --from=ak_to_mbtiles /fgb/ak/*.mbtiles /fgb/ak/
# COPY --from=gl_to_mbtiles /fgb/gl/*.mbtiles /fgb/gl/
COPY --from=hi_to_mbtiles /fgb/hi/*.mbtiles /fgb/hi/
COPY --from=prvi_to_mbtiles /fgb/prvi/*.mbtiles /fgb/prvi/
COPY --from=conus_to_mbtiles /fgb/conus/*.mbtiles /fgb/conus/

RUN tile-join -o divides.mbtiles /fgb/ak/divides.mbtiles /fgb/hi/divides.mbtiles /fgb/prvi/divides.mbtiles /fgb/conus/divides.mbtiles
RUN tile-join -o flowpaths.mbtiles /fgb/ak/flowpaths.mbtiles /fgb/hi/flowpaths.mbtiles /fgb/prvi/flowpaths.mbtiles /fgb/conus/flowpaths.mbtiles
# RUN tile-join -o hydrolocations.mbtiles /fgb/gl/hydrolocations.mbtiles /fgb/conus/hydrolocations.mbtiles
RUN tile-join -x hl_reference -o gages.mbtiles  /fgb/conus/gages.mbtiles

FROM base AS convert_to_pmtiles
WORKDIR /mbtiles/merged
COPY --from=merge_mbtiles /mbtiles/merged/ .
COPY --from=conus_to_mbtiles /fgb/conus/hydrolocations.mbtiles .
COPY --from=conus_to_mbtiles /fgb/conus/gages.mbtiles .
RUN pmtiles convert --no-deduplication divides.mbtiles divides.pmtiles
RUN pmtiles convert --no-deduplication flowpaths.mbtiles flowpaths.pmtiles
RUN pmtiles convert --no-deduplication hydrolocations.mbtiles hydrolocations.pmtiles
RUN pmtiles convert --no-deduplication gages.mbtiles gages.pmtiles

FROM convert_to_pmtiles AS output
WORKDIR /output
COPY --from=convert_to_pmtiles /mbtiles/merged/*.pmtiles .
