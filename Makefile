deploy:
	ssh isu12q-1 " \
		cd /home/isucon; \
		git checkout .; \
		git fetch; \
		git checkout $(BRANCH); \
		git reset --hard origin/$(BRANCH)"
	scp -r ./webapp/go isu12q-2:/home/isucon/webapp/
	scp -r ./webapp/go isu12q-3:/home/isucon/webapp/
	ssh isu12q-2 "sudo dd of=/home/isucon/webapp/docker-compose-go.yml" < ./webapp/docker-compose-go.yml
	ssh isu12q-3 "sudo dd of=/home/isucon/webapp/docker-compose-go.yml" < ./webapp/docker-compose-go.yml
	ssh isu12q-2 " \
		cd /home/isucon; \
		rm -f webapp/tenant_db/*.db; \
		cp -r initial_data/*.db webapp/tenant_db/"
	ssh isu12q-3 " \
		rm -f webapp/tenant_db/*.db; \
		cp -r initial_data/*.db webapp/tenant_db/"

build:
	ssh isu12q-1 " \
		cd /home/isucon/webapp/go; \
		make isuports"

go-deploy:
	scp ./webapp/go/isuports isu12q-1:/home/isucon/webapp/go/

go-deploy-dir:
	scp -r ./webapp/go isu12q-1:/home/isucon/webapp/

restart:
	ssh isu12q-1 "sudo systemctl restart isuports.service"
	ssh isu12q-2 "sudo systemctl restart isuports.service"
	ssh isu12q-3 "sudo systemctl restart isuports.service"

mysql-deploy:
	ssh isu12q-1 "sudo dd of=/etc/mysql/mysql.conf.d/mysqld.cnf" < ./etc/mysql/mysql.conf.d/mysqld.cnf

mysql-rotate:
	ssh isu12q-1 "sudo rm -f /var/log/mysql/mysql-slow.log"

mysql-restart:
	ssh isu12q-1 "sudo systemctl restart mysql.service"

nginx-deploy:
	ssh isu12q-1 "sudo dd of=/etc/nginx/nginx.conf" < ./etc/nginx/nginx.conf
	ssh isu12q-1 "sudo dd of=/etc/nginx/sites-available/isuports.conf" < ./etc/nginx/sites-available/isuports.conf

nginx-rotate:
	ssh isu12q-1 "sudo rm -f /var/log/nginx/access.log"

nginx-reload:
	ssh isu12q-1 "sudo systemctl reload nginx.service"

nginx-restart:
	ssh isu12q-1 "sudo systemctl restart nginx.service"

nginx-log:
	ssh isu12q-1 "sudo tail -f /var/log/nginx/access.log"

journalctl-1:
	ssh isu12q-1 "sudo journalctl -xef"

journalctl-2:
	ssh isu12q-2 "sudo journalctl -xef"

journalctl-3:
	ssh isu12q-3 "sudo journalctl -xef"

.PHONY: bench
bench:
	ssh isu12q-bench " \
		cd /home/isucon/bench; \
		./bench -target-addr 172.31.43.140:443"

pt-query-digest:
	ssh isu12q-1 "sudo pt-query-digest --limit 10 /var/log/mysql/mysql-slow.log"

ALPSORT=sum
# /api/player/competition/[0-9a-z\-]+/ranking
# /api/player/player/[0-9a-z]+
# /api/organizer/competition/[0-9a-z\-]+/finish
# /api/organizer/competition/[0-9a-z\-]+/score
# /api/organizer/player/[0-9a-z\-]+/disqualified
# /api/admin/tenants/billing
ALPM=/api/player/competition/[0-9a-z\-]+/ranking,/api/player/player/[0-9a-z]+,/api/organizer/competition/[0-9a-z\-]+/finish,/api/organizer/competition/[0-9a-z\-]+/score,/api/organizer/player/[0-9a-z\-]+/disqualified,/api/admin/tenants/billing
OUTFORMAT=count,method,uri,min,max,sum,avg,p99

alp:
	ssh isu12q-1 "sudo alp ltsv --file=/var/log/nginx/access.log --nosave-pos --pos /tmp/alp.pos --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q"

.PHONY: pprof
pprof:
	ssh isu12q-1 " \
		/usr/bin/go tool pprof -seconds=80 /home/isucon/webapp/go/isuports http://localhost:6060/debug/pprof/profile"

pprof-show:
	$(eval latest := $(shell ssh isu12q-1 "ls -rt ~/pprof/ | tail -n 1"))
	scp isu12q-1:~/pprof/$(latest) ./pprof
	go tool pprof -http=":1080" ./pprof/$(latest)

pprof-kill:
	ssh isu12q-1 "pgrep -f 'pprof' | xargs kill;"

pprof-2:
	ssh isu12q-2 " \
		/usr/bin/go tool pprof -seconds=80 /home/isucon/webapp/go/isuports http://localhost:6060/debug/pprof/profile"

pprof-show-2:
	$(eval latest := $(shell ssh isu12q-2 "ls -rt ~/pprof/ | tail -n 1"))
	scp isu12q-2:~/pprof/$(latest) ./pprof
	go tool pprof -http=":1080" ./pprof/$(latest)
