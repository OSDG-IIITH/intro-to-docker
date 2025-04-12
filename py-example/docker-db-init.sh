#!/bin/bash

set -eu

psql -v ON_ERROR_STOP=1 -U postgres -f /schema.sql
