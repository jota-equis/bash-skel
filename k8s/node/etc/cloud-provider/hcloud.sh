#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
VERSION=0.3
# · ---
TOKEN="${1}";

BDIR=/srv/local/etc
CNIP="node.ip-addr
