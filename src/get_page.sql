CREATE PROCEDURE get_page (
    IN p_tableName VARCHAR(64),
    IN p_filterColumn VARCHAR(64),
    IN p_filterValue INT,
    IN p_keyColumn VARCHAR(64),
    IN p_direction VARCHAR(5),
    IN p_startKey INT,
    IN p_limit INT,
    IN p_commitHash VARCHAR(64)
)
BEGIN

DECLARE v_subQuery TEXT;
DECLARE v_innerQuery TEXT;
DECLARE v_whereClause VARCHAR(200);
DECLARE v_orderClause VARCHAR(200);

IF p_direction = 'after' THEN
SET v_whereClause = concat(p_keycolumn, ' > ?');
SET v_orderClause = concat('ORDER BY ', p_keycolumn, ' ASC LIMIT ?');
ELSE
SET v_whereClause = concat(p_keycolumn, ' < ?');
SET v_orderClause = concat('ORDER BY ', p_keycolumn, ' DESC LIMIT ?');
END IF;

IF p_commithash IS NOT NULL AND p_commithash <> '' THEN
SET v_subQuery = concat(
    'SELECT * FROM ', p_tablename,
    ' AS OF ''', p_commithash, ''''
);
ELSE
SET v_subQuery = concat(
    'SELECT * FROM ', p_tablename
);
END IF;

SET v_innerQuery = concat(
    v_subquery,
    ' WHERE ', p_filtercolumn, ' = ? ',
    ' AND ', v_whereclause, ' ',
    v_orderclause
);

IF p_direction = 'after' THEN
SET @finalQuery = v_innerQuery;
ELSE
SET @finalQuery = concat(
    'SELECT * FROM (', v_innerquery, ') AS t ORDER BY t.', p_keycolumn, ' ASC'
);
END IF;

PREPARE stmt FROM @finalQuery;
EXECUTE stmt USING @p_filterValue, @p_startKey, @p_limit;
DEALLOCATE PREPARE stmt;

END;
