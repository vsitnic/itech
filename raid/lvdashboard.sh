#!/bin/bash

pvsinfo=$(pvdisplay -C --noheadings | awk '{print $1,$2,$5,$6}')
pvolumes=$(echo "${pvsinfo}" | cut -d ' ' -f 1)

for pvolume in ${pvolumes}; do
  echo "+================================================"
  echo -n "| "
  grep $(basename ${pvolume}) /proc/mdstat
  echo "${pvsinfo}" | grep ${pvolume} | awk '{print "| PV "$1", VG "$2", PSize "$3", PFree "$4"."}'
  echo "+------------------------------------------------"
  vgroup=$(echo "${pvsinfo}" | grep ${pvolume} | awk '{print $2'})
  lvdisplay ${vgroup} -C | awk '{print "|",$1,$2,$4}' | column -t
done

echo "+================================================"
