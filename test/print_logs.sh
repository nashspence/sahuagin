mariadb -h localhost -P 3306 -u root -ptest -D sahuagin --batch --raw -e "
SELECT JSON_ARRAYAGG(
    JSON_OBJECT(
        'id', id,
        'log_time', log_time,
        'procedure_name', procedure_name,
        'log_message', log_message
    )
) FROM debug_log;"