
new: clean up init

clean: halt
	vagrant destroy -f --parallel

up:
	vagrant up
	bin/setup-ssh.sh

init: initdb deploy

halt:
	vagrant halt

sync:
	ssh primary sudo ntpdate -u time.pool.aliyun.com
	ssh standby sudo ntpdate -u time.pool.aliyun.com
	ssh offline sudo ntpdate -u time.pool.aliyun.com
	ssh monitor sudo ntpdate -u time.pool.aliyun.com

initdb:
	ssh primary sudo -iu postgres /opt/bin/init-primary.sh 'postgres://replicator:replicating@standby.test.pg:5432/test'
	ssh standby sudo -iu postgres /opt/bin/init-standby.sh 'postgres://replicator:replicating@primary.test.pg:5432/test?application_name=standby'
	ssh offline sudo -iu postgres /opt/bin/init-offline.sh 'postgres://replicator:replicating@primary.test.pg:5432/test?apply_delay=10min'
	ssh monitor sudo -iu postgres /opt/bin/init-primary.sh 'postgres:///meta'

deploy:
	node/primary.test.pg/deploy init
	node/monitor/deploy init

ssh:
	bin/setup-ssh.sh

dns:
	sudo bin/setup-dns.sh

test:
	ssh primary sudo -iu postgres pgbench test -T1800 -c5 -n

suspend:
	vagrant suspend

resume:
	vagrant resume

status:
	vagrant status

download:
	pkg/download.sh

download-yum:
	vagrant up primary
	ssh primary sudo /opt/bin/install-utils.sh download
	rm -rf pkg/yum
	scp -r primary:/opt/pkg/yum pkg/yum

view:
	open 'http://monitor:3000/d/yQg0oM_ik/db-module?orgId=1&from=now-30m&to=now&refresh=1m'

prom:
	open http://monitor:9090

dump-monitor:
	scp monitor:/var/lib/grafana/grafana.db node/monitor/


.PHONY: new clean up init halt initdb deploy ssh dns test suspend resume status download download-yum view prom dump-monitor
