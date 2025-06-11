CREATE OR REPLACE FUNCTION debug_log(
    p_procedure_name varchar,
    p_log_message text
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO debug_log (procedure_name, log_message, log_time)
    VALUES (p_procedure_name, p_log_message, now());
END;
$$;

