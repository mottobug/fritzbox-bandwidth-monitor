#!/bin/bash
# 
#  upnp2mrtg - Monitoring AVM Fritz!Box With MRTG
#  This versions have been reported as working: 3030, 5050, 7050, 7141 and 7170
#
#  Copyright (C) 2005 Michael Tomschitz <michael.tomschitz@ANetzB.de>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#  The latest version of this software can be obtained here:
# 
#  http://www.ANetzB.de/upnp2mrtg/
#
#  $Id: upnp2mrtg,v 1.9 2008/02/09 15:37:57 tomcat Exp $

# default configuration
HOST="fritz.box"
PORT="49000"
NETCAT="netcat"

# if available, read configuration 
test -f /etc/upnp2mrtg.cfg && . /etc/upnp2mrtg.cfg

case $NETCAT in
    bash) nc="shell_netcat" ;;
    netcat) nc="netcat" ;;
    nc_q) nc="nc -q 1" ;;
    *) nc="nc" ;;
esac

ver_txt="upnp2mrtg, version $Revision: 1.9 $
Copyright (C) 2005-2008 Michael Tomschitz
upnp2mrtg comes with ABSOLUTELY NO WARRANTY. This is free software,
and you are welcome to redistribute it under certain conditions."

help_txt="\
Usage: upnp2mrtg [-a <host>] [-p <port>] [-P] [-d] [-h] [-i] [-t] [-v] [-V]

  -a <host>    hostname or ip adress of upnp device (default: $HOST)
  -p <port>    port to connect (default: $PORT)
  -P           query packets instead of bytes
  -d           debug mode
  -h           show help and exit
  -i <outfile> get all igd description
  -t           test connection
  -v           show upnp2mrtg version and exit
  -V           be verbose for testing
"

while getopts "a:dhi:p:PtvV" option; do
  case $option in
    a) HOST="$OPTARG";;
    d) set -x ;;
    h) echo "$help_txt"; exit 0;;
    i) MODE=igd; IGDXML="$OPTARG";;
    p) PORT="$OPTARG";;
    P) PACKET_MODE=true;;
    t) MODE="test";;
    v) echo "$ver_txt"; exit 0;;
    V) VERBOSE=true;;
    ?) exit 1;;
  esac
done

# functions
request_header () {
echo "POST /igdupnp/control/$4 HTTP/1.0
HOST: $1:$2
CONTENT-LENGTH: $3
CONTENT-TYPE: text/xml; charset=\"utf-8\"
SOAPACTION: \"urn:schemas-upnp-org:service:$5:1#$6\""
}
soap_form () {
  echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<s:Envelope
        xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"
        s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
    <s:Body>
        <u:$1 xmlns:u=\"urn:schemas-upnp-org:service:$2:1\" />
    </s:Body>
</s:Envelope>"
}
get_attribute () {
    _get_attribute_start_tag () { echo "${2#*<$1>*}"; }
    _get_attribute_end_tag () { echo "${2%*</$1>*}"; }
    _get_attribute_tag () { _get_attribute_start_tag "$1" "`_get_attribute_end_tag $1 "$2"`" ; }
    _get_attribute_num () { echo $#; }
    if [ `_get_attribute_num $1` -gt 1 ]; then
        get_attribute "${1#* }" "`_get_attribute_tag "${1%% *}" "$2"`"
    else
        _get_attribute_tag "${1}" "$2"
    fi
}
modulo_time () {
  echo "$((${1} / ${2})) $((${1} % ${2}))"
}
shell_netcat () {
  exec 5<>/dev/tcp/$1/$2; cat >&5; cat <&5;
}
get_response () {
  _get_response_rs="`echo "$1" | $nc $HOST $PORT 2>/dev/null`"
  _get_response_rv=$?
  echo "$_get_response_rs"
  if ${VERBOSE:-false}; then
    echo
    echo "---- REQUEST: ----">&2
    echo "$1">&2
    echo "---- RESPONSE: ----">&2
    echo "$_get_response_rs">&2
    echo "----">&2
  fi
  return $_get_response_rv
}
request_header_http () {
echo "GET $3 HTTP/1.0

"
}
ws_operation () {
  request="`soap_form "$1" WANCommonInterfaceConfig`"
  post="`request_header $HOST $PORT ${#request} WANCommonIFC1 WANCommonInterfaceConfig "$1"`

$request"
rs="`get_response "$post"`"
if [ $? -eq 0 ]; then
  echo "`get_attribute "$2" "$rs"`"
fi
}

case $MODE in
  test)
    echo "GET /any.xml HTTP/1.0
" | $nc $HOST $PORT >/dev/null
    if [ $? -eq 0 ]; then
      echo "OK"; exit 0
    else
      echo "Connection Error"; exit 1
    fi;;
  igd)
    if [ -f "$IGDXML" ];then
      echo "ERROR: $IGDXML: File exists.">&2; exit 1
    fi
    for igd in any igdconnSCPD igddesc igddslSCPD igdicfgSCPD; do
      request="`request_header_http $HOST $PORT /$igd.xml`
" 
      rs="`get_response "$request"`"
      if [ "$IGDXML" = "-" ]; then
        echo "---- $igd.xml ----
$rs"
      else
        echo "---- $igd.xml ----
$rs" >> "$IGDXML"
      fi
    done;;
   *)
# get uptime
request="`soap_form GetStatusInfo WANIPConnection`"
post="`request_header $HOST $PORT ${#request} WANIPConn1 WANIPConnection GetStatusInfo`

$request"
# rs="`echo "$post" | $nc $HOST $PORT 2>/dev/null`"
rs="`get_response "$post"`"
if [ $? -eq 0 ]; then
  ut=`get_attribute NewUptime "$rs"`

  # calculate days + hours, minutes, seconds
  s=`modulo_time $ut 60`
  m=`modulo_time ${s% *} 60`
  h=`modulo_time ${m% *} 24`
fi

# get data in/out
if ${PACKET_MODE:-false}; then
  b1="`ws_operation GetTotalPacketsReceived NewTotalPacketsReceived`"
  b2="`ws_operation GetTotalPacketsSent NewTotalPacketsSent`"
else
  b1="`ws_operation GetAddonInfos NewTotalBytesReceived`"
  b2="`ws_operation GetAddonInfos NewTotalBytesSent`"
fi

# output for mrtg
printf "%s\n%s\n%d days %.2d:%.2d:%.2d h (online)\nFRITZ!Box\n" \
  "${b1:-UNKNOWN}" "${b2:-UNKNOWN}" "${h% *}" "${h#* }" "${m#* }" "${s#* }"
  ;;
esac

