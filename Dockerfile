FROM ubuntu:25.10 AS base
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
RUN nala install -y vim

WORKDIR /tippecanoe
RUN git clone --single-branch --depth=1 https://github.com/felt/tippecanoe.git \
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
RUN sqlite3 /raw_hf/ak_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT *, CAST((substr(id,4)) AS INTEGER) as num_id, CAST((substr(flowpaths.toid,5)) AS INTEGER) as num_toid, (ChSlp*1000) as ChSlpx1000 FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/ak_nextgen.gpkg "CREATE TABLE divides_new AS SELECT *, CAST((substr(divide_id,5)) AS INTEGER) as num_id FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -simplify 1 -nlt PROMOTE_TO_MULTI -s_srs EPSG:3338 -t_srs CRS:84 flowpaths.fgb /raw_hf/ak_nextgen.gpkg flowpaths
RUN ogr2ogr -simplify 1  -s_srs EPSG:3338 -t_srs CRS:84 divides.fgb /raw_hf/ak_nextgen.gpkg divides

FROM install_tools AS gl_to_geojson
# great lakes canada region
# gl divides flowpaths EPSG:3338       hydrolocations, pois EPSG:5070
WORKDIR /geojson/gl
RUN sqlite3 /raw_hf/gl_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT *, CAST((substr(id,4)) AS INTEGER) as num_id FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' as fa ON fa.link = flowpaths.id; DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
# # RUN sqlite3 /raw_hf/gl_nextgen.gpkg "CREATE TABLE divides_new AS SELECT *, CAST((substr(divide_id,5)) AS INTEGER) as num_id FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -simplify 1 -nlt PROMOTE_TO_MULTI -s_srs EPSG:3338 -t_srs CRS:84 flowpaths.fgb /raw_hf/gl_nextgen.gpkg flowpaths
RUN ogr2ogr -simplify 1  -s_srs EPSG:3338 -t_srs CRS:84 divides.fgb /raw_hf/gl_nextgen.gpkg divides
RUN ogr2ogr -simplify 1  -s_srs EPSG:5070 -t_srs CRS:84 hydrolocations.fgb /raw_hf/gl_nextgen.gpkg hydrolocations
#-lco SIGNIFICANT_FIGURES=7
FROM install_tools AS hi_to_geojson
# hi ESRI:102007
WORKDIR /geojson/hi
RUN sqlite3 /raw_hf/hi_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT *, CAST((substr(id,4)) AS INTEGER) as num_id, CAST((substr(flowpaths.toid,5)) AS INTEGER) as num_toid, (ChSlp*1000) as ChSlpx1000 FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/hi_nextgen.gpkg "CREATE TABLE divides_new AS SELECT *, CAST((substr(divide_id,5)) AS INTEGER) as num_id FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -simplify 1 -nlt PROMOTE_TO_MULTI -s_srs ESRI:102007 -t_srs CRS:84 flowpaths.fgb /raw_hf/hi_nextgen.gpkg flowpaths
RUN ogr2ogr -simplify 1  -s_srs ESRI:102007 -t_srs CRS:84 divides.fgb /raw_hf/hi_nextgen.gpkg divides

FROM install_tools AS prvi_to_geojson
# prvi EPSG:6566
WORKDIR /geojson/prvi
RUN sqlite3 /raw_hf/prvi_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT *, CAST((substr(id,4)) AS INTEGER) as num_id, CAST((substr(flowpaths.toid,5)) AS INTEGER) as num_toid, (ChSlp*1000) as ChSlpx1000 FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/prvi_nextgen.gpkg "CREATE TABLE divides_new AS SELECT *, CAST((substr(divide_id,5)) AS INTEGER) as num_id FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -simplify 1 -nlt PROMOTE_TO_MULTI -s_srs EPSG:6566 -t_srs CRS:84 flowpaths.fgb /raw_hf/prvi_nextgen.gpkg flowpaths
RUN ogr2ogr -simplify 1  -s_srs EPSG:6566 -t_srs CRS:84 divides.fgb /raw_hf/prvi_nextgen.gpkg divides

FROM install_tools AS conus_to_geojson
# conus EPSG:5070
WORKDIR /geojson/conus
RUN sqlite3 /raw_hf/conus_nextgen.gpkg "CREATE TABLE flowpaths_new AS SELECT *, CAST((substr(id,4)) AS INTEGER) as num_id, CAST((substr(flowpaths.toid,5)) AS INTEGER) as num_toid, (ChSlp*1000) as ChSlpx1000 FROM flowpaths LEFT OUTER JOIN 'flowpath-attributes' USING ('id'); DROP TABLE flowpaths; ALTER TABLE flowpaths_new RENAME TO flowpaths;"
RUN sqlite3 /raw_hf/conus_nextgen.gpkg "CREATE TABLE divides_new AS SELECT *, CAST((substr(divide_id,5)) AS INTEGER) as num_id FROM divides LEFT OUTER JOIN 'divide-attributes' USING ('divide_id'); DROP TABLE divides; ALTER TABLE divides_new RENAME TO divides;"
RUN ogr2ogr -simplify 1 -nlt PROMOTE_TO_MULTI -s_srs EPSG:5070 -t_srs CRS:84 flowpaths.fgb /raw_hf/conus_nextgen.gpkg flowpaths
RUN ogr2ogr -simplify 1  -s_srs EPSG:5070 -t_srs CRS:84 divides.fgb /raw_hf/conus_nextgen.gpkg divides
# RUN ogr2ogr -simplify 1  -s_srs EPSG:5070 -t_srs CRS:84 hydrolocations.fgb /raw_hf/conus_nextgen.gpkg hydrolocations

FROM ak_to_geojson AS ak_to_mbtiles
RUN tippecanoe -S 10 -pn -pS --single-precision -z12 -Z3 --use-attribute-for-id=num_id -aI -o flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int  -y alt -T alt:int -y TopWdth -T TopWdth:int -l ak_flowpaths --extend-zooms-if-still-dropping flowpaths.fgb -P
RUN tippecanoe -S 10 -pn --single-precision -z12 -Z5 --use-attribute-for-id=num_id -aI -o divides.mbtiles -l ak_divides --extend-zooms-if-still-dropping divides.fgb -P
# RUN tile-join -pk -o ak.mbtiles flowpaths.mbtiles divides.mbtiles

FROM gl_to_geojson AS gl_to_mbtiles
RUN tippecanoe -S 10 -pn -pS -D 8 -j '{ "*": [ "any", [ ">=", "$zoom", 5 ], [ ">", "order", 3 ] ] }' --single-precision -j '{ "*": [ "attribute-filter", "order", [ "==", "$zoom", 1 ] ] }'  -y order -T order:int -z12 -Z5 --use-attribute-for-id=num_id -aI -o flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l gl_flowpaths --extend-zooms-if-still-dropping flowpaths.fgb -P
RUN tippecanoe -S 10 -pn -pf -ah -ab  --single-precision -z12 -Z7 --use-attribute-for-id=num_id -aI -o divides.mbtiles -l gl_divides --extend-zooms-if-still-dropping divides.fgb -P
# RUN tippecanoe -S 10 -pn --single-precision -x fid -z10 -Z2 -r1 --cluster-distance=5 -o hydrolocations.mbtiles -l gl_hydrolocations hydrolocations.fgb -P
# RUN tippecanoe -S 10 -pn --single-precision -x fid -z10 -Z3 -r1 -j '{ "*": [ "any", [ "==", "hl_reference", "gages" ]] }' -o gages.mbtiles -l gl_gages hydrolocations.fgb -P

# RUN tile-join -pk -o gl.mbtiles flowpaths.mbtiles divides.mbtiles hydrolocations.mbtiles gages.mbtiles

FROM hi_to_geojson AS hi_to_mbtiles
RUN tippecanoe -S 10 -pn -pS --single-precision -z12 -Z5 --use-attribute-for-id=num_id -aI -o flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l hi_flowpaths --extend-zooms-if-still-dropping flowpaths.fgb -P
RUN tippecanoe -S 10 -pn --single-precision -z12 -Z5 --use-attribute-for-id=num_id -aI -o divides.mbtiles -l hi_divides --extend-zooms-if-still-dropping divides.fgb -P
# RUN tile-join -pk -o hi.mbtiles flowpaths.mbtiles divides.mbtiles

FROM prvi_to_geojson AS prvi_to_mbtiles
RUN tippecanoe -S 10 -pn -pS --single-precision -z12 -Z5 --use-attribute-for-id=num_id -aI -o flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l prvi_flowpaths --extend-zooms-if-still-dropping flowpaths.fgb -P
RUN tippecanoe -S 10 -pn --single-precision -z12 -Z5 --use-attribute-for-id=num_id -aI -o divides.mbtiles -l prvi_divides --extend-zooms-if-still-dropping divides.fgb -P
# RUN tile-join -pk -o prvi.mbtiles flowpaths.mbtiles divides.mbtiles
#
FROM conus_to_geojson AS conus_to_mbtiles
# -S 20 -D 8 ok up until zoom 7.5 ish
RUN tippecanoe -S 10 -pn -ah -pf -ab -j '{ "*": [ "any", [ ">=", "$zoom", 6 ], [ ">", "order", 4 ] ] }' -D 8 --coalesce-densest-as-needed -E num_id:comma -j '{ "*": [ "attribute-filter", "order", [ "==", "$zoom", 1 ] ] }' --single-precision -y order -T order:int -z6 -Z5 --use-attribute-for-id=num_id -aI -o low_zoom_flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l conus_flowpaths flowpaths.fgb -P
RUN tippecanoe -S 10 -pn -ah -pf -ab -j '{ "*": [ "any", [ ">=", "$zoom", 6 ], [ ">", "order", 2 ] ] }' -D 10 --coalesce-densest-as-needed -E num_id:comma -j '{ "*": [ "attribute-filter", "order", [ "==", "$zoom", 1 ] ] }' --single-precision -y order -T order:int -z7 -Z7 --use-attribute-for-id=num_id -aI -o 7_zoom_flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l conus_flowpaths flowpaths.fgb -P
RUN tippecanoe -S 10 -pn -ah -pf -ab -j '{ "*": [ "any", [ ">=", "$zoom", 6 ], [ ">", "order", 2 ] ] }' -E num_id:comma -j '{ "*": [ "attribute-filter", "order", [ "==", "$zoom", 1 ] ] }' --single-precision -y order -T order:int -z12 -Z8 --use-attribute-for-id=num_id -aI -o high_zoom_flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l conus_flowpaths --extend-zooms-if-still-dropping flowpaths.fgb -P
RUN tile-join -pk -o flowpaths.mbtiles high_zoom_flowpaths.mbtiles low_zoom_flowpaths.mbtiles 7_zoom_flowpaths.mbtiles


# RUN tippecanoe -S 15 -m 6 -pS -j '{ "*": [ "any", [ ">=", "$zoom", 5 ], [ ">", "order", 3 ] ] }' -j '{ "*": [ "attribute-filter", "order", [ "==", "$zoom", 1 ] ] }' --single-precision -y order -T order:int -z12 -Z5 --use-attribute-for-id=num_id -aI -o flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l conus_flowpaths --extend-zooms-if-still-dropping flowpaths.fgb -P
# RUN tippecanoe -S 10  -pn -pS -m 7 -al -E num_id:comma --single-precision -z4 -Z3 --use-attribute-for-id=num_id -aI -o low_zoom_flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int -l conus_flowpaths flowpaths.fgb -P

RUN tippecanoe -S 10 -pn -pf -ah -ab --single-precision -z12 -Z7 --use-attribute-for-id=num_id -aI -o divides.mbtiles -l conus_divides --extend-zooms-if-still-dropping divides.fgb -P
# RUN tippecanoe -S 10 -pn --single-precision -g 2 --coalesce-smallest-as-needed -E divide_id:comma -z4 -Z3 --use-attribute-for-id=num_id -aI -o low_zoom_divides.mbtiles -l conus_divides divides.fgb -P
# RUN tile-join -pk -o divides.mbtiles high_zoom_divides.mbtiles
# RUN tippecanoe -S 10 -pn --single-precision -x fid -z10 -Z2 -r1 --cluster-distance=5 -o hydrolocations.mbtiles -l conus_hydrolocations hydrolocations.fgb -P
# RUN tippecanoe -S 10 -pn --single-precision -x fid -z10 -Z3 -r1 -j '{ "*": [ "any", [ "==", "hl_reference", "gages" ]] }' -o gages.mbtiles -l conus_gages hydrolocations.fgb -P

# RUN tile-join -pk -o conus.mbtiles flowpaths.mbtiles divides.mbtiles hydrolocations.mbtiles gages.mbtiles

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
# RUN tile-join -pk -o all_gages.mbtiles ./*/gages.mbtiles
# RUN tile-join -pk -o all_hydrolocations.mbtiles ./*/hydrolocations.mbtiles

FROM merge_by_layer AS pmtiles
RUN pmtiles convert --no-deduplication all_flowpaths.mbtiles all_flowpaths.pmtiles
RUN pmtiles convert --no-deduplication all_divides.mbtiles all_divides.pmtiles
# RUN pmtiles convert --no-deduplication all_gages.mbtiles all_gages.pmtiles
# RUN pmtiles convert --no-deduplication all_hydrolocations.mbtiles all_hydrolocations.pmtiles


#tippecanoe -z6 -o vpu.mbtiles --coalesce-densest-as-needed --force -P vpu.fgb
#tippecanoe -S 10 -pn --single-precision -z12 -Z5 --use-attribute-for-id=id -o flowpaths.mbtiles -y num_toid -T num_toid:int -y ChSlpx1000 -T ChSlpx1000:int -y Length_m -T Length_m:int -y alt -T alt:int -y TopWdth -T TopWdth:int --coalesce-densest-as-needed --extend-zooms-if-still-dropping flowpaths.fgb --force -P
