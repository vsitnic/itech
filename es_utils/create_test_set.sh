for day in `seq 1 9`; do
    curl -s -XPUT http://localhost:9200'/'jump-secure-2015-09-0${day}
    curl -s -k -XPOST http://localhost:9200'/_aliases' -d '{"actions":[{"add":{"alias":"'jump-secure'","index":"'jump-secure-2015-09-0${day}'"}}]}'
    echo
done
exit

for day in `seq 10 21`; do
#    curl -s -XPUT http://localhost:9200'/'jump-secure-2015-09-${day}
    curl -s -k -XPOST http://localhost:9200'/_aliases' -d '{"actions":[{"add":{"alias":"'jump-secure'","index":"'jump-secure-2015-09-${day}'"}}]}'
    echo
done
