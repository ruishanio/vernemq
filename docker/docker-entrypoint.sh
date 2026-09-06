#!/bin/sh
set -e

if [ "$#" -eq 0 ]; then
    exec vernemq console -noshell -noinput
fi

exec "$@"
