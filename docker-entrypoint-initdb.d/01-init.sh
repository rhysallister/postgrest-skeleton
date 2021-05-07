echo "==============="
echo "   01-init.sh  "
echo "==============="


echo "#        Additions made below this line     " >> $PGDATA/postgresql.conf

echo "shared_preload_libraries = 'pg_stat_statements, pg_cron'" >> $PGDATA/postgresql.conf
echo "pg_stat_statements.max = 10000" >> $PGDATA/postgresql.conf
echo "pg_stat_statements.track = all" >> $PGDATA/postgresql.conf
echo "cron.database_name = 'skltn' " >> $PGDATA/postgresql.conf
# echo "port = 55559" >>$PGDATA/postgresql.conf

echo "host	skltn	postgres	all	trust" >> $PGDATA/pg_hba.conf



pg_ctl restart
