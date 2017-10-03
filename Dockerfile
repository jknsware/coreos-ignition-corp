FROM nginx:1.13.5-alpine
MAINTAINER jason@jknsware.com

LABEL dockerfile_location=https://github.com/jknsware/coreos-igintion-corp \
  image_name=jknsware\coreos-ignition-corp \
  base_image=nginx:1.13.5-alpine

# CoreOS Ignition config converted to json with ct
COPY config.json /usr/share/nginx/html