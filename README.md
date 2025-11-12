# EcontroSmartHome


in /etc/config/modbus_client staan de configuratie voor de modbus client
>
    config main 'main'
            option debug '0'
            option enabled '1'
            option db_path '/var/run/modbus_client/modbus.db'
>
    config rtu_device '2'
            option full_duplex_enabled '0'
            option name 'Test'
            option device '/dev/rs485'
            option baudrate '115200'
            option flowcontrol 'none'
            option databits '8'
            option parity 'none'
            option stopbits '1'
            option enabled '1'
>
    config request_3 '4'
            option broadcast '0'
            option name 'SOC'
            option no_brackets '0'
            option store_on_change_only '0'
            option enabled '1'
            option reg_count '1'
            option function '3'
            option first_reg '32105'
            option data_type '16bit_uint_hi_first'

dit is een voorbeeld hoe zon config file eruit ziet:

> ubus call modbus_client.rpc get_tag_value '{"id":"3.11", "index":0, "count":1}'

**index**: This specifies the starting position within the requested data array or register set. In most cases, 0 means "start from the first register/value."

**count**: This tells the RPC how many consecutive values to retrieve starting from index. In your example, count:1 means "read just one value."