FROM ubuntu AS base
RUN apt update && apt install -y nala

FROM base AS download_fabrics
WORKDIR /raw_hf
# ADD https://lynker-spatial.s3-us-west-2.amazonaws.com/hydrofabric/v2.2/conus/conus_nextgen.gpkg /raw_hf/conus_nextgen.gpkg
# ADD https://lynker-spatial.s3-us-west-2.amazonaws.com/hydrofabric/v2.2/ak/ak_nextgen.gpkg /raw_hf/ak_nextgen.gpkg
# ADD https://lynker-spatial.s3-us-west-2.amazonaws.com/hydrofabric/v2.2/gl/gl_nextgen.gpkg /raw_hf/gl_nextgen.gpkg
# ADD https://lynker-spatial.s3-us-west-2.amazonaws.com/hydrofabric/v2.2/hi/hi_nextgen.gpkg /raw_hf/hi_nextgen.gpkg
# ADD https://lynker-spatial.s3-us-west-2.amazonaws.com/hydrofabric/v2.2/prvi/prvi_nextgen.gpkg /raw_hf/prvi_nextgen.gpkg
COPY --from=local_copy conus_nextgen.gpkg /raw_hf/conus_nextgen.gpkg
COPY --from=local_copy ak_nextgen.gpkg /raw_hf/ak_nextgen.gpkg
COPY --from=raw_copy gl_nextgen.gpkg /raw_hf/gl_nextgen.gpkg
COPY --from=local_copy hi_nextgen.gpkg /raw_hf/hi_nextgen.gpkg
COPY --from=local_copy prvi_nextgen.gpkg /raw_hf/prvi_nextgen.gpkg

FROM download_fabrics AS install_tools
# Install all the required tools
# protomaps, tippecanoe, gdal
RUN nala install -y build-essential libsqlite3-dev zlib1g-dev wget gdal-bin git

WORKDIR /tippecanoe
RUN git clone --single-branch --depth=1 https://github.com/mapbox/tippecanoe.git \
    && cd tippecanoe \
    && make -j \
    && make install

WORKDIR /pmtiles
ADD https://github.com/protomaps/go-pmtiles/releases/download/v1.22.1/go-pmtiles_1.22.1_Linux_x86_64.tar.gz /pmtiles/pmtiles.tar.gz
RUN tar -xvf pmtiles.tar.gz
RUN mv pmtiles /usr/local/bin
RUN nala install -y libsqlite3-mod-spatialite sqlite3


FROM install_tools AS ak_to_geojson
# ak EPSG:3338
WORKDIR /geojson/ak
RUN sqlite3 /raw_hf/ak_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT * FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/ak_nextgen.gpkg "CREATE TABLE divides_new AS SELECT * FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 flowpaths.geojson /raw_hf/ak_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 divides.geojson /raw_hf/ak_nextgen.gpkg divides

FROM install_tools AS gl_to_geojson
# great lakes canada region
# gl divides flowpaths EPSG:3338       hydrolocations, pois EPSG:5070
WORKDIR /geojson/gl
RUN sqlite3 /raw_hf/gl_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT * FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' as fa ON fa.link = flowpaths.id; DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
# RUN sqlite3 /raw_hf/gl_nextgen.gpkg "CREATE TABLE divides_new AS SELECT * FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 flowpaths.geojson /raw_hf/gl_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs EPSG:3338 -t_srs CRS:84 divides.geojson /raw_hf/gl_nextgen.gpkg divides
RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 hydrolocations.geojson /raw_hf/gl_nextgen.gpkg hydrolocations

FROM install_tools AS hi_to_geojson
# hi ESRI:102007
WORKDIR /geojson/hi
RUN sqlite3 /raw_hf/hi_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT * FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/hi_nextgen.gpkg "CREATE TABLE divides_new AS SELECT * FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -s_srs ESRI:102007 -t_srs CRS:84 flowpaths.geojson /raw_hf/hi_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs ESRI:102007 -t_srs CRS:84 divides.geojson /raw_hf/hi_nextgen.gpkg divides

FROM install_tools AS prvi_to_geojson
# prvi EPSG:6566
WORKDIR /geojson/prvi
RUN sqlite3 /raw_hf/prvi_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT * FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/prvi_nextgen.gpkg "CREATE TABLE divides_new AS SELECT * FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -s_srs EPSG:6566 -t_srs CRS:84 flowpaths.geojson /raw_hf/prvi_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs EPSG:6566 -t_srs CRS:84 divides.geojson /raw_hf/prvi_nextgen.gpkg divides

FROM install_tools AS conus_to_geojson
# conus EPSG:5070
WORKDIR /geojson/conus
RUN sqlite3 /raw_hf/conus_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT * FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/conus_nextgen.gpkg "CREATE TABLE divides_new AS SELECT * FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 flowpaths.geojson /raw_hf/conus_nextgen.gpkg flowpaths
RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 divides.geojson /raw_hf/conus_nextgen.gpkg divides
RUN ogr2ogr -s_srs EPSG:5070 -t_srs CRS:84 hydrolocations.geojson /raw_hf/conus_nextgen.gpkg hydrolocations

FROM ak_to_geojson AS ak_to_mbtiles
RUN tippecanoe -z10 -Z7 -o flowpaths.mbtiles -l ak_flowpaths --drop-densest-as-needed --extend-zooms-if-still-dropping flowpaths.geojson -P
RUN tippecanoe -z10 -Z7 -o divides.mbtiles -l ak_divides --drop-densest-as-needed --extend-zooms-if-still-dropping divides.geojson -P
RUN tile-join -pk -o ak.mbtiles flowpaths.mbtiles divides.mbtiles

FROM gl_to_geojson AS gl_to_mbtiles
RUN tippecanoe -z10 -Z7 -o flowpaths.mbtiles -l gl_flowpaths --drop-densest-as-needed --extend-zooms-if-still-dropping flowpaths.geojson -P
RUN tippecanoe -z10 -Z7 -o divides.mbtiles -l gl_divides --drop-densest-as-needed --extend-zooms-if-still-dropping divides.geojson -P
RUN tippecanoe -z10 -Z2 -r1 --cluster-distance=5 -o hydrolocations.mbtiles -l gl_hydrolocations hydrolocations.geojson -P
RUN tippecanoe -z10 -Z3 -r1 -j '{ "*": [ "any", [ "==", "hl_reference", "gages" ]] }' -o gages.mbtiles -l gl_gages hydrolocations.geojson -P

RUN tile-join -pk -o gl.mbtiles flowpaths.mbtiles divides.mbtiles hydrolocations.mbtiles gages.mbtiles

FROM hi_to_geojson AS hi_to_mbtiles
RUN tippecanoe -z10 -Z7 -o flowpaths.mbtiles -l hi_flowpaths --drop-densest-as-needed --extend-zooms-if-still-dropping flowpaths.geojson -P
RUN tippecanoe -z10 -Z7 -o divides.mbtiles -l hi_divides --drop-densest-as-needed --extend-zooms-if-still-dropping divides.geojson -P
RUN tile-join -pk -o hi.mbtiles flowpaths.mbtiles divides.mbtiles

FROM prvi_to_geojson AS prvi_to_mbtiles
RUN tippecanoe -z10 -Z7 -o flowpaths.mbtiles -l prvi_flowpaths --drop-densest-as-needed --extend-zooms-if-still-dropping flowpaths.geojson -P
RUN tippecanoe -z10 -Z7 -o divides.mbtiles -l prvi_divides --drop-densest-as-needed --extend-zooms-if-still-dropping divides.geojson -P
RUN tile-join -pk -o prvi.mbtiles flowpaths.mbtiles divides.mbtiles

FROM conus_to_geojson AS conus_to_mbtiles
RUN tippecanoe -z10 -Z7 -o flowpaths.mbtiles -l conus_flowpaths --drop-densest-as-needed --extend-zooms-if-still-dropping flowpaths.geojson -P
RUN tippecanoe -z10 -Z7 -o divides.mbtiles -l conus_divides --drop-densest-as-needed --extend-zooms-if-still-dropping divides.geojson -P
RUN tippecanoe -z10 -Z2 -r1 --cluster-distance=5 -o hydrolocations.mbtiles -l conus_hydrolocations hydrolocations.geojson -P
RUN tippecanoe -z10 -Z3 -r1 -j '{ "*": [ "any", [ "==", "hl_reference", "gages" ]] }' -o gages.mbtiles -l conus_gages hydrolocations.geojson -P

RUN tile-join -pk -o conus.mbtiles flowpaths.mbtiles divides.mbtiles hydrolocations.mbtiles gages.mbtiles

FROM install_tools AS merge_mbtiles
WORKDIR /mbtiles/merged
COPY --from=ak_to_mbtiles /geojson/ak/ak.mbtiles .
COPY --from=gl_to_mbtiles /geojson/gl/gl.mbtiles .
COPY --from=hi_to_mbtiles /geojson/hi/hi.mbtiles .
COPY --from=prvi_to_mbtiles /geojson/prvi/prvi.mbtiles .
COPY --from=conus_to_mbtiles /geojson/conus/conus.mbtiles .
RUN tile-join -pk -o merged.mbtiles ak.mbtiles gl.mbtiles hi.mbtiles prvi.mbtiles conus.mbtiles

FROM merge_mbtiles AS convert_to_pmtiles
WORKDIR /mbtiles/merged
RUN pmtiles convert --no-deduplication merged.mbtiles merged.pmtiles

FROM install_tools AS merge_by_layer
WORKDIR /mbtiles/merged
COPY --from=ak_to_mbtiles /geojson/ak/ ./ak/
COPY --from=gl_to_mbtiles /geojson/gl/ ./gl/
COPY --from=hi_to_mbtiles /geojson/hi/ ./hi/
COPY --from=prvi_to_mbtiles /geojson/prvi/ ./prvi/
COPY --from=conus_to_mbtiles /geojson/conus/ ./conus/
RUN tile-join -pk -o all_flowpaths.mbtiles ./*/flowpaths.mbtiles
RUN tile-join -pk -o all_divides.mbtiles ./*/divides.mbtiles
RUN tile-join -pk -o all_gages.mbtiles ./*/gages.mbtiles
RUN tile-join -pk -o all_hydrolocations.mbtiles ./*/hydrolocations.mbtiles

FROM merge_by_layer AS pmtiles
RUN pmtiles convert --no-deduplication all_flowpaths.mbtiles all_flowpaths.pmtiles
RUN pmtiles convert --no-deduplication all_divides.mbtiles all_divides.pmtiles
RUN pmtiles convert --no-deduplication all_gages.mbtiles all_gages.pmtiles
RUN pmtiles convert --no-deduplication all_hydrolocations.mbtiles all_hydrolocations.pmtiles


#tippecanoe -z6 -o vpu.mbtiles --coalesce-densest-as-needed --force -P vpu.geojson
#tippecanoe -z10 -Z7 -o flowpaths.mbtiles --coalesce-densest-as-needed --extend-zooms-if-still-dropping flowpaths.geojson --force -P
