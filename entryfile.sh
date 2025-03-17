#!/bin/bash
#set -ex

dlt-daemon&
routingmanagerd&
/radio-service& #> /var/radio.log 2>&1 &
#/radio-client
/bin/bash
