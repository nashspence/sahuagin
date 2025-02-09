PGPASSWORD="test" psql -h localhost -p 5432 -U postgres -d sahuagin -t -A -c "
SELECT json_agg(
    json_build_object(
        'id', id,
        'log_time', log_time,
        'procedure_name', procedure_name,
        'log_message', log_message
    )
) FROM debug_log;"
