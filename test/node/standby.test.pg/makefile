NODE := $(shell basename $(PWD) | cut -d"." -f1)
PGLOG = /pg/data/log/postgresql-$(shell date +%a).csv

ssh:
	ssh $(NODE)

status:
	ssh $(NODE) "systemctl status"

pg-start:
	ssh $(NODE) "sudo systemctl start postgresql"

pg-stop:
	ssh $(NODE) "sudo systemctl stop postgresql"

pg-restart:
	ssh $(NODE) "sudo systemctl restart postgresql"

pg-reload:
	ssh $(NODE) "sudo systemctl reload postgresql"

pg-status:
	ssh $(NODE) "sudo systemctl status postgresql"

pg-show-conf:
	ssh $(NODE) "sudo cat /pg/data/postgresql.conf"

pg-show-hba:
	ssh $(NODE) "sudo cat /pg/data/pg_hba.conf"

pg-show-recovery:
	ssh $(NODE) "sudo cat /pg/data/recovery.conf"

pg-show-status:
	ssh $(NODE) "sudo -iu postgres psql -xc 'SELECT pg_is_in_recovery();'"

pg-show-change:
	ssh $(NODE) sudo -iu postgres ls /pg/change | sort -n

pg-change-history:
	ssh $(NODE) sudo -iu postgres cat /pg/change/history

pg-change-log:
	ssh $(NODE) sudo -iu postgres cat /pg/change/history

pg-show-log:
	ssh $(NODE) sudo cat $(PGLOG)

pg-tail-log:
	ssh $(NODE) sudo tail -f $(PGLOG)

pg-update-bin:
	ssh $(NODE) "sudo rm -rf /tmp/bin"
	scp -r ../../bin/pg $(NODE):/tmp/bin > /dev/null
	ssh $(NODE) "sudo rm -rf /pg/bin; sudo mv -f /tmp/bin /pg/bin;sudo chown -R postgres:postgres /pg/bin"

pg-update-conf:
	scp postgresql.conf $(NODE):/tmp/postgresql.conf
	ssh $(NODE) 'sudo -iu postgres /pg/bin/deploy.sh /tmp/postgresql.conf'

pg-update-hba:
	scp pg_hba.conf $(NODE):/tmp/pg_hba.conf
	ssh $(NODE) 'sudo -iu postgres /pg/bin/deploy.sh /tmp/pg_hba.conf'

pg-update-recovery:
	scp recovery.conf $(NODE):/tmp/recovery.conf
	ssh $(NODE) 'sudo -iu postgres /pg/bin/deploy.sh /tmp/recovery.conf'

pg-show-activity:
	ssh $(NODE) "sudo -iu postgres psql -xc 'TABLE pg_stat_activity;'"

pg-show-replication:
	ssh $(NODE) "sudo -iu postgres psql -xc 'TABLE pg_stat_replication;'"

pg-show-replication-slots:
	ssh $(NODE) "sudo -iu postgres psql -xc 'TABLE pg_replication_slots;'"

pg-version:
	ssh $(NODE) pg_ctl --version

pg-kill:
	ssh $(NODE) "sudo -iu postgres psql -c 'SELECT count(pg_terminate_backend(pid)) FROM pg_stat_activity WHERE pid <> pg_backend_pid();'"

pgb-start:
	ssh $(NODE) "sudo systemctl start pgbouncer"

pgb-stop:
	ssh $(NODE) "sudo systemctl stop pgbouncer"

pgb-restart:
	ssh $(NODE) "sudo systemctl restart pgbouncer"

pgb-reload:
	ssh $(NODE) "sudo systemctl reload pgbouncer"

pgb-status:
	ssh $(NODE) "sudo systemctl status pgbouncer"

pgb-show-log:
	ssh $(NODE) sudo cat /var/log/pgbouncer/pgbouncer.log

pgb-tail-log:
	ssh $(NODE) sudo tail -f /var/log/pgbouncer/pgbouncer.log

pgb-update-conf:
	scp pgbouncer.ini $(NODE):/tmp/pgbouncer.ini
	ssh $(NODE) 'sudo -iu postgres /pg/bin/deploy.sh /tmp/pgbouncer.ini'



postgres-exporter-start:
	ssh $(NODE) "sudo systemctl start postgres_exporter"

postgres-exporter-stop:
	ssh $(NODE) "sudo systemctl stop postgres_exporter"

postgres-exporter-restart:
	ssh $(NODE) "sudo systemctl restart postgres_exporter"

postgres-exporter-status:
	ssh $(NODE) "sudo systemctl status postgres_exporter"

postgres-exporter-update-conf:
	scp postgres_exporter.yaml $(NODE):/tmp/postgres_exporter.yaml
	ssh $(NODE) 'sudo -iu postgres /pg/bin/deploy.sh /tmp/postgres_exporter.yaml

postgres-exporter-update-env:
	scp postgres_exporter.env $(NODE):/tmp/postgres_exporter.env
	ssh $(NODE) 'sudo -iu postgres /pg/bin/deploy.sh /tmp/postgres_exporter.env




consul-start:
	ssh $(NODE) "sudo systemctl start consul"

consul-stop:
	ssh $(NODE) "sudo systemctl stop consul"

consul-restart:
	ssh $(NODE) "sudo systemctl restart consul"

consul-reload:
	ssh $(NODE) "sudo systemctl reload consul"

consul-status:
	ssh $(NODE) "sudo systemctl status consul"

consul-show-conf:
	ssh $(NODE) "sudo cat /etc/consul.d/consul.json"

consul-show-nodes:
	ssh $(NODE) "consul catalog nodes"

consul-show-services:
	ssh $(NODE) "consul catalog services"

consul-update-conf:
	scp consul.json $(NODE):/tmp/consul.json
	ssh $(NODE) 'sudo mv -f /tmp/consul.json /etc/consul.d/consul.json; sudo chown -R consul:consul /etc/consul.d/'