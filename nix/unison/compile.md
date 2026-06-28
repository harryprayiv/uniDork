# uniDork build transcript

​```ucm
scratch/main> pull @unison/base lib.base
scratch/main> pull @unison/json/releases/1.4.2 lib.unison_json_1_4_2
scratch/main> pull @unison/xml/releases/2.1.2 lib.unison_xml_2_1_2
scratch/main> pull @unison/http/releases/16.0.0 lib.unison_http_16_0_0
scratch/main> pull @runarorama/postgres/releases/2.5.1 runarorama_postgres_2_5_1
scratch/main> load patches.u
scratch/main> update
scratch/main> load scratch.u
scratch/main> add
scratch/main> compile uniDork.cli unidork-import
​```