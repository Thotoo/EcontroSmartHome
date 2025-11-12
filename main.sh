#!/bin/bash
ID=3.4
INDEX=0
COUNT=1
rm ./logs/test_log.txt -f
while :
do
        GET_MODBUS_VALUE=$(ubus call modbus_client.rpc get_tag_value "{\"id\":\"$ID\",\"index\":$INDEX,\"count\":$COUNT}")
        PARSED_MODBUS_VALUE=$(echo "$GET_MODBUS_VALUE" | jsonfilter -e '@.values[0]')
        CURRENT_DATE=$(date)
        echo "State of charge: $PARSED_MODBUS_VALUE     $CURRENT_DATE" >> ./logs/test_log.txt
    sleep 5
done

