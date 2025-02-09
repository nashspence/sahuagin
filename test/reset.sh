PGPASSWORD="test" psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS sahuagin;"
PGPASSWORD="test" psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE sahuagin;"
